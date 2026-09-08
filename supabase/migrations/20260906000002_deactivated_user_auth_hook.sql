-- SteriCord QA remediation D-07 (FF-20), second half: "Prevent deactivated
-- users from starting new sessions or refreshing existing sessions."
--
-- The is_active_user()/current_organization_id() fix in the previous
-- migration closes the "already-issued JWT still works" hole at the data
-- layer -- that's the one FF-20 actually exercised, and it's necessarily
-- the authoritative check (a token minted a second before deactivation is
-- still cryptographically valid until it expires; no hook can reach back
-- and revoke it after the fact). This migration adds Supabase's Custom
-- Access Token Hook as defense in depth at the *front* door: GoTrue calls
-- it on every login and every token refresh, before a token is minted, so
-- a deactivated user is stopped from getting a fresh token at all rather
-- than being let in and only blocked once they try to read data.
--
-- QA remediation D-08: the retest confirmed this hook DOES stop the
-- login/refresh (no token is issued), but the first pass rejected it by
-- `raise exception`, which GoTrue surfaces as a bare HTTP 500 -- it passes
-- the raw Postgres error straight through (`{"code":"P0001","message":...}`)
-- rather than parsing the exception message as JSON. Verified empirically
-- against this local GoTrue (v2.195.0) via `docker logs`: an exception's
-- message text is never inspected for structure, no matter what shape it
-- is -- the response is always the generic unexpected_failure/500 pair.
--
-- The controlled-rejection path for a Postgres Auth Hook is instead a
-- *return value* convention: return `{"error": {"http_code": ..., "message":
-- ...}}` as the function's normal jsonb result (do not raise). GoTrue
-- inspects the returned jsonb for an "error" key and maps http_code to the
-- response status. Confirmed live: a deactivated user's password login and
-- refresh both now return 403 with a stable `{"msg":"Account is
-- deactivated"}` body instead of 500; an active user's login is unaffected
-- (still 200), and a wrong password is unaffected (still 400).
create or replace function public.reject_deactivated_user_token(event jsonb)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_user_id uuid := (event->>'user_id')::uuid;
  v_is_active boolean;
begin
  select is_active into v_is_active from public.profiles where id = v_user_id;

  -- No profile row yet (e.g. mid sign-up, before handle_new_auth_user's
  -- trigger has run) is not the same as deactivated -- don't block it.
  if v_is_active is false then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message', 'Account is deactivated'
      )
    );
  end if;

  return event;
end;
$$;

comment on function public.reject_deactivated_user_token is 'Custom Access Token Hook: refuses to mint a login/refresh token for a deactivated profile. Defense in depth -- the authoritative enforcement is is_active_user()/current_organization_id() in RLS, since a token minted before deactivation stays valid until this hook runs again.';

revoke all on function public.reject_deactivated_user_token(jsonb) from public, anon, authenticated;
grant execute on function public.reject_deactivated_user_token(jsonb) to supabase_auth_admin;
