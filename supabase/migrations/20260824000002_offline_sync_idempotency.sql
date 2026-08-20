-- SteriCord Phase 8: offline sync support (master prompt section 42).
--
-- The mobile capture flow (section 42: Capture -> Encrypted Local Storage ->
-- Local Operation ID -> Sync Queue -> ... -> Server Synchronization -> Server
-- Acknowledgement) needs the server side of that contract: a client that
-- queues an operation offline and retries it after a dropped connection must
-- be able to replay the exact same call without creating a duplicate
-- point-of-use record. A network timeout doesn't tell the client whether the
-- server actually processed the request before the connection dropped -- so
-- "retry" and "duplicate" are indistinguishable without a server-side ledger
-- keyed by the client's own locally-generated operation id.
--
-- OT point-of-use is the one write path mobile field staff actually need
-- offline (an OT with no signal recording a scan-and-verify) -- the CSSD-side
-- cycle functions (start_cycle/complete_cycle) run in a fixed sterilizer
-- room with reliable wifi, so they're out of scope for this migration.

create table public.client_operation_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_operation_id uuid not null,
  operation_name text not null,
  result_entity_id uuid not null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (organization_id, client_operation_id)
);

comment on table public.client_operation_log is 'Idempotency ledger for offline-queued mobile writes. A retried sync with the same client_operation_id returns the original result instead of creating a duplicate row -- see record_point_of_use_verification.';

create index idx_client_operation_log_org_client_op on public.client_operation_log(organization_id, client_operation_id);

alter table public.client_operation_log enable row level security;

create policy client_operation_log_select on public.client_operation_log
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

-- No insert/update/delete policy: written only from inside
-- record_point_of_use_verification (SECURITY DEFINER), never directly.

drop function if exists public.record_point_of_use_verification(uuid, public.verification_result, uuid, text, text, text, uuid);

create or replace function public.record_point_of_use_verification(
  p_pack_id uuid,
  p_result public.verification_result,
  p_department_id uuid default null,
  p_patient_reference text default null,
  p_encounter_reference text default null,
  p_notes text default null,
  p_ai_analysis_id uuid default null,
  p_client_operation_id uuid default null
)
returns public.point_of_use_records
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pack public.instrument_packs;
  v_eligible boolean;
  v_reason text;
  v_record public.point_of_use_records;
  v_incident public.incidents;
  v_ai_result public.verification_result;
  v_ai_confidence numeric;
  v_existing_result_id uuid;
begin
  select * into v_pack from public.instrument_packs where id = p_pack_id;
  if v_pack is null then
    raise exception 'Pack % not found', p_pack_id;
  end if;
  if v_pack.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_pack.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR','OT_NURSE']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to record a point-of-use verification';
  end if;

  -- Idempotent replay: a client retrying a sync it's not sure landed gets
  -- back the original record rather than a second scan-and-verify event.
  if p_client_operation_id is not null then
    select result_entity_id into v_existing_result_id
    from public.client_operation_log
    where organization_id = v_pack.organization_id
      and client_operation_id = p_client_operation_id;

    if v_existing_result_id is not null then
      select * into v_record from public.point_of_use_records where id = v_existing_result_id;
      return v_record;
    end if;
  end if;

  select eligible, reason into v_eligible, v_reason from public.check_pack_eligibility(p_pack_id);
  if not v_eligible then
    raise exception 'Pack is not eligible for use: %', v_reason;
  end if;

  if p_ai_analysis_id is not null then
    select suggested_result, confidence into v_ai_result, v_ai_confidence
    from public.ai_analyses
    where id = p_ai_analysis_id and organization_id = v_pack.organization_id;
  end if;

  insert into public.point_of_use_records (
    organization_id, pack_id, department_id, patient_reference, encounter_reference,
    eligibility_passed, eligibility_reason, verification_result, notes, scanned_by
  ) values (
    v_pack.organization_id, p_pack_id, p_department_id, p_patient_reference, p_encounter_reference,
    true, null, p_result, p_notes, auth.uid()
  )
  returning * into v_record;

  if p_client_operation_id is not null then
    insert into public.client_operation_log (
      organization_id, client_operation_id, operation_name, result_entity_id, created_by
    ) values (
      v_pack.organization_id, p_client_operation_id, 'record_point_of_use_verification', v_record.id, auth.uid()
    );
  end if;

  insert into public.verifications (
    organization_id, entity_type, entity_id, verification_type,
    ai_suggested_result, ai_confidence, human_result, verified_by, notes
  ) values (
    v_pack.organization_id, 'instrument_pack', p_pack_id, 'OT_POINT_OF_USE',
    v_ai_result, v_ai_confidence, p_result, auth.uid(), p_notes
  );

  if p_result = 'PASS' then
    update public.instrument_packs set status = 'USED' where id = p_pack_id;

  elsif p_result = 'FAIL' then
    update public.instrument_packs set status = 'QUARANTINED' where id = p_pack_id;

    insert into public.incidents (
      organization_id, source_type, related_entity_type, related_entity_id,
      point_of_use_record_id, status, priority, description, detected_by
    ) values (
      v_pack.organization_id, 'OT_VERIFICATION_FAILURE', 'instrument_pack', p_pack_id,
      v_record.id, 'ALERTED', 'CRITICAL',
      coalesce(p_notes, 'OT point-of-use verification failed for pack ' || v_pack.pack_code),
      auth.uid()
    )
    returning * into v_incident;

    insert into public.quarantines (
      organization_id, source_incident_id, scope_type, scope_id, reason, initiated_by
    ) values (
      v_pack.organization_id, v_incident.id, 'PACK', p_pack_id,
      coalesce(p_notes, 'OT point-of-use verification failure'), auth.uid()
    );

    perform public.notify_roles(
      v_pack.organization_id,
      array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR']::public.user_role[],
      'CRITICAL',
      'OT verification failed: ' || v_pack.pack_code,
      coalesce(p_notes, 'Pack quarantined pending investigation.'),
      'instrument_pack',
      p_pack_id
    );

    perform public.log_audit_event(
      v_pack.organization_id, 'INCIDENT_CREATED', 'incident', v_incident.id,
      null, jsonb_build_object('pack_id', p_pack_id, 'source_type', 'OT_VERIFICATION_FAILURE')
    );
    perform public.log_audit_event(
      v_pack.organization_id, 'QUARANTINE_STARTED', 'instrument_pack', p_pack_id,
      null, jsonb_build_object('source_incident_id', v_incident.id)
    );
  end if;

  perform public.log_audit_event(
    v_pack.organization_id, 'OT_VERIFICATION_COMPLETED', 'instrument_pack', p_pack_id,
    null, jsonb_build_object('result', p_result, 'point_of_use_record_id', v_record.id, 'ai_analysis_id', p_ai_analysis_id)
  );

  return v_record;
end;
$$;
