-- SteriCord Phase 1: immutable, hash-chained audit trail
-- Master prompt section 29 + section 50 test: "Critical audit events cannot
-- be modified through normal application access." Rows are inserted only via
-- the security-definer public.log_audit_event() function; there is no
-- update or delete policy, so PostgREST/RLS blocks both operations outright.

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_user_id uuid references public.profiles(id) on delete set null,
  event_type public.audit_event_type not null,
  entity_type text not null,
  entity_id uuid,
  previous_state jsonb,
  new_state jsonb,
  occurred_at timestamptz not null default now(),
  session_id text,
  device_id text,
  metadata jsonb,
  event_hash text not null,
  previous_event_hash text
);

comment on table public.audit_events is 'Append-only audit log, hash-chained per organization. No update/delete RLS policy exists on this table by design.';

create index idx_audit_events_organization_id on public.audit_events(organization_id);
create index idx_audit_events_entity on public.audit_events(entity_type, entity_id);
create index idx_audit_events_occurred_at on public.audit_events(occurred_at);

create or replace function public.log_audit_event(
  p_organization_id uuid,
  p_event_type public.audit_event_type,
  p_entity_type text,
  p_entity_id uuid,
  p_previous_state jsonb default null,
  p_new_state jsonb default null,
  p_session_id text default null,
  p_device_id text default null,
  p_metadata jsonb default null
)
returns public.audit_events
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_previous_hash text;
  v_new_hash text;
  v_row public.audit_events;
begin
  select event_hash into v_previous_hash
  from public.audit_events
  where organization_id = p_organization_id
  order by occurred_at desc, id desc
  limit 1;

  v_new_hash := encode(
    digest(
      coalesce(v_previous_hash, '') || '|' ||
      p_organization_id::text || '|' ||
      p_event_type::text || '|' ||
      p_entity_type || '|' ||
      coalesce(p_entity_id::text, '') || '|' ||
      coalesce(p_new_state::text, '') || '|' ||
      clock_timestamp()::text,
      'sha256'
    ),
    'hex'
  );

  insert into public.audit_events (
    organization_id, actor_user_id, event_type, entity_type, entity_id,
    previous_state, new_state, session_id, device_id, metadata,
    event_hash, previous_event_hash
  ) values (
    p_organization_id, auth.uid(), p_event_type, p_entity_type, p_entity_id,
    p_previous_state, p_new_state, p_session_id, p_device_id, p_metadata,
    v_new_hash, v_previous_hash
  )
  returning * into v_row;

  return v_row;
end;
$$;

comment on function public.log_audit_event is 'Sole entry point for writing audit_events; computes the hash chain link so history cannot be silently reordered.';

alter table public.audit_events enable row level security;

-- Select only. No insert/update/delete policy: writes happen exclusively
-- through log_audit_event(), which runs as security definer and bypasses RLS.
create policy audit_events_select on public.audit_events
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );
