-- SteriCord Phase 7: compliance, retention, and audit-chain verification.

-- Master prompt section 23: "Maximum retention: 7 years" for the two
-- domains that actually hold binary/historical evidence -- evidence_files
-- and audit_events. This only records *when* a record becomes eligible for
-- policy-controlled deletion; it does not delete anything itself (that's a
-- scheduled job, Phase 8 territory, and deleting an audit event before its
-- retention window closes would defeat the point of an audit trail).

alter table public.evidence_files
  add column retention_expires_at timestamptz;

alter table public.audit_events
  add column retention_expires_at timestamptz;

update public.evidence_files set retention_expires_at = captured_at + interval '7 years';
update public.audit_events set retention_expires_at = occurred_at + interval '7 years';

alter table public.evidence_files alter column retention_expires_at set not null;
alter table public.audit_events alter column retention_expires_at set not null;

create or replace function public.set_evidence_retention()
returns trigger
language plpgsql
as $$
begin
  new.retention_expires_at := new.captured_at + interval '7 years';
  return new;
end;
$$;

create trigger trg_evidence_files_retention
  before insert on public.evidence_files
  for each row execute function public.set_evidence_retention();

create or replace function public.set_audit_event_retention()
returns trigger
language plpgsql
as $$
begin
  new.retention_expires_at := new.occurred_at + interval '7 years';
  return new;
end;
$$;

create trigger trg_audit_events_retention
  before insert on public.audit_events
  for each row execute function public.set_audit_event_retention();

create index idx_evidence_files_retention_expires_at on public.evidence_files(retention_expires_at);
create index idx_audit_events_retention_expires_at on public.audit_events(retention_expires_at);

-- Fix: log_audit_event() originally hashed clock_timestamp() (read at hash-
-- computation time) while the row's own occurred_at column got a SEPARATE
-- now() from the table's column default -- two independent clock reads
-- microseconds apart. That meant the exact string baked into event_hash
-- was never persisted anywhere, so the hash could never actually be
-- re-derived from the stored row -- only hash-to-hash chain linkage could
-- be checked, not that a row's own hash still matches its own content.
-- Capturing one timestamp and using it for both the inserted row and the
-- hash input makes the hash fully reproducible from stored data, which is
-- what verify_audit_chain() below depends on. Signature is unchanged, so
-- CREATE OR REPLACE is safe here (contrast with the Phase 6 migration,
-- where the argument list changed and a DROP was required first).

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
  v_occurred_at timestamptz := clock_timestamp();
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
      v_occurred_at::text,
      'sha256'
    ),
    'hex'
  );

  insert into public.audit_events (
    organization_id, actor_user_id, event_type, entity_type, entity_id,
    previous_state, new_state, occurred_at, session_id, device_id, metadata,
    event_hash, previous_event_hash
  ) values (
    p_organization_id, auth.uid(), p_event_type, p_entity_type, p_entity_id,
    p_previous_state, p_new_state, v_occurred_at, p_session_id, p_device_id, p_metadata,
    v_new_hash, v_previous_hash
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- Cryptographic chain verification: walks audit_events in occurred_at order
-- per organization, recomputing each event_hash from the row's own stored
-- columns using the exact formula log_audit_event() uses, and comparing
-- against what's stored -- a genuine content-integrity check, not just
-- hash-to-hash linkage. A mismatch means either the row's content changed
-- after insertion (impossible through the app -- there is no UPDATE policy
-- -- but this also catches direct superuser tampering or a restore-from-
-- backup gap) or the chain order was disturbed. Read-only.

-- OUT parameters are named out_* specifically so they can't collide with
-- audit_events' own column names (occurred_at, event_type) inside the
-- query below -- that exact collision ("column reference ... is
-- ambiguous") is what an earlier version of this function hit in testing.
create or replace function public.verify_audit_chain(p_organization_id uuid)
returns table (
  out_event_id uuid,
  out_occurred_at timestamptz,
  out_event_type public.audit_event_type,
  out_issue text
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row record;
  v_running_hash text := null;
  v_computed text;
begin
  if p_organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;

  for v_row in
    select id, occurred_at, event_type, entity_type, entity_id, new_state, event_hash, previous_event_hash
    from public.audit_events
    where organization_id = p_organization_id
    order by occurred_at asc, id asc
  loop
    if v_row.previous_event_hash is distinct from v_running_hash then
      out_event_id := v_row.id;
      out_occurred_at := v_row.occurred_at;
      out_event_type := v_row.event_type;
      out_issue := 'previous_event_hash does not match the prior event''s event_hash';
      return next;
    end if;

    v_computed := encode(
      digest(
        coalesce(v_row.previous_event_hash, '') || '|' ||
        p_organization_id::text || '|' ||
        v_row.event_type::text || '|' ||
        v_row.entity_type || '|' ||
        coalesce(v_row.entity_id::text, '') || '|' ||
        coalesce(v_row.new_state::text, '') || '|' ||
        v_row.occurred_at::text,
        'sha256'
      ),
      'hex'
    );

    if v_computed <> v_row.event_hash then
      out_event_id := v_row.id;
      out_occurred_at := v_row.occurred_at;
      out_event_type := v_row.event_type;
      out_issue := 'event_hash does not match a recomputation from this row''s own stored content';
      return next;
    end if;

    v_running_hash := v_row.event_hash;
  end loop;

  return;
end;
$$;

comment on function public.verify_audit_chain is 'Read-only integrity check: recomputes each event_hash from stored content and checks chain linkage. Returns zero rows when the chain is fully intact.';
