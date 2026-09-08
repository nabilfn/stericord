-- SteriCord QA remediation D-07 (FF-20): profiles.is_active=false did not
-- block an already-issued JWT from reading protected data. The JWT itself
-- carries no is_active claim, and none of the three RLS helper functions --
-- current_organization_id(), user_has_role(), is_system_admin() -- ever
-- consulted profiles.is_active. Every tenant-scoped policy in the schema
-- routes through one of these three (STABLE, SECURITY DEFINER, and always
-- executed fresh against the database on each request -- there is no
-- session-level caching to go stale), so fixing them here closes the gap at
-- its single point of control instead of touching every policy that calls
-- them.
--
-- This does NOT depend on the JWT changing at all: a deactivated user's
-- existing token still authenticates as that user (auth.uid() still
-- resolves), but every RLS check that asks "what can this user see/do"
-- now correctly answers "nothing tenant-scoped" the moment is_active flips,
-- on the very next request -- exactly the "already-issued JWT" scenario
-- FF-20 tested.

create or replace function public.current_organization_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select organization_id from public.profiles where id = auth.uid() and is_active;
$$;

create or replace function public.user_has_role(target_org uuid, roles public.user_role[])
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.profiles p on p.id = ur.user_id
    where ur.user_id = auth.uid()
      and ur.organization_id = target_org
      and ur.role = any(roles)
      and ur.revoked_at is null
      and p.is_active
  );
$$;

create or replace function public.is_system_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.profiles p on p.id = ur.user_id
    where ur.user_id = auth.uid()
      and ur.role = 'SYSTEM_ADMIN'
      and ur.revoked_at is null
      and p.is_active
  );
$$;

-- A handful of policies check auth.uid() directly instead of going through
-- the helpers above (profiles_update_self, notifications_select,
-- notifications_update_own) -- those need their own explicit is_active
-- check, since deactivating a user should stop them reading/updating even
-- their own rows, not just cross-tenant ones.
create or replace function public.is_active_user()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select is_active from public.profiles where id = auth.uid()), false);
$$;

comment on function public.is_active_user() is 'True only for a currently-active profile. Used by the few RLS policies that check auth.uid() directly instead of going through current_organization_id()/user_has_role()/is_system_admin(), all three of which already enforce is_active internally.';

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update
  using (id = auth.uid() and public.is_active_user())
  with check (id = auth.uid() and organization_id = public.current_organization_id());

drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select
  using ((recipient_user_id = auth.uid() and public.is_active_user()) or public.is_system_admin());

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications
  for update
  using (recipient_user_id = auth.uid() and public.is_active_user())
  with check (recipient_user_id = auth.uid());
