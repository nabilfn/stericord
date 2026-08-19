-- SteriCord Phase 1: table/function privileges for PostgREST roles.
-- RLS policies restrict rows, but Postgres also requires table-level GRANTs
-- before RLS is even evaluated. Recent Supabase defaults do not
-- auto-expose new tables, so this is required explicitly.
-- Future migrations that add tables must extend these grants (the DEFAULT
-- PRIVILEGES clause below covers tables created afterwards by this role).

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on
  public.organizations,
  public.departments,
  public.profiles,
  public.user_roles,
  public.equipment,
  public.equipment_status_events,
  public.audit_events
to authenticated;

grant execute on function
  public.current_organization_id(),
  public.user_has_role(uuid, public.user_role[]),
  public.is_system_admin(),
  public.log_audit_event(uuid, public.audit_event_type, text, uuid, jsonb, jsonb, text, text, jsonb)
to authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema public
  grant execute on functions to authenticated;
