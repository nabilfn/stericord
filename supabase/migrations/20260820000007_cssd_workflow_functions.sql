-- SteriCord Phase 2: CSSD workflow state-machine functions.
-- These are the only way cycle_status / pack_status ever change. Each does
-- its own org + role authorization check (security definer bypasses RLS),
-- validates the source state, performs the transition, cascades to related
-- packs where the workflow requires it, and writes an audit_events row.

create or replace function public.start_cycle(p_cycle_id uuid)
returns public.sterilization_cycles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.sterilization_cycles;
begin
  select * into v_cycle from public.sterilization_cycles where id = p_cycle_id;
  if v_cycle is null then
    raise exception 'Cycle % not found', p_cycle_id;
  end if;
  if v_cycle.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_cycle.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR','CSSD_TECHNICIAN']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to start a cycle';
  end if;
  if v_cycle.cycle_status <> 'CREATED' then
    raise exception 'Cycle must be CREATED to start (current status: %)', v_cycle.cycle_status;
  end if;

  update public.sterilization_cycles
  set cycle_status = 'RUNNING', started_at = coalesce(started_at, now())
  where id = p_cycle_id
  returning * into v_cycle;

  update public.instrument_packs
  set status = 'STERILIZING'
  where sterilization_cycle_id = p_cycle_id and status = 'PACKED';

  perform public.log_audit_event(
    v_cycle.organization_id, 'CYCLE_STARTED', 'sterilization_cycle', p_cycle_id,
    null, jsonb_build_object('cycle_status', v_cycle.cycle_status)
  );

  return v_cycle;
end;
$$;

create or replace function public.complete_cycle(
  p_cycle_id uuid,
  p_temperature numeric default null,
  p_pressure numeric default null,
  p_hold_time_seconds integer default null
)
returns public.sterilization_cycles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.sterilization_cycles;
begin
  select * into v_cycle from public.sterilization_cycles where id = p_cycle_id;
  if v_cycle is null then
    raise exception 'Cycle % not found', p_cycle_id;
  end if;
  if v_cycle.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_cycle.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR','CSSD_TECHNICIAN']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to complete a cycle';
  end if;
  if v_cycle.cycle_status <> 'RUNNING' then
    raise exception 'Cycle must be RUNNING to complete (current status: %)', v_cycle.cycle_status;
  end if;

  update public.sterilization_cycles
  set cycle_status = 'COMPLETED',
      completed_at = now(),
      temperature = coalesce(p_temperature, temperature),
      pressure = coalesce(p_pressure, pressure),
      hold_time_seconds = coalesce(p_hold_time_seconds, hold_time_seconds)
  where id = p_cycle_id
  returning * into v_cycle;

  update public.instrument_packs
  set status = 'PENDING_VERIFICATION'
  where sterilization_cycle_id = p_cycle_id and status = 'STERILIZING';

  perform public.log_audit_event(
    v_cycle.organization_id, 'CYCLE_COMPLETED', 'sterilization_cycle', p_cycle_id,
    null, jsonb_build_object('cycle_status', v_cycle.cycle_status)
  );

  return v_cycle;
end;
$$;

create or replace function public.submit_cycle_for_verification(p_cycle_id uuid)
returns public.sterilization_cycles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.sterilization_cycles;
  v_evidence_count integer;
begin
  select * into v_cycle from public.sterilization_cycles where id = p_cycle_id;
  if v_cycle is null then
    raise exception 'Cycle % not found', p_cycle_id;
  end if;
  if v_cycle.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_cycle.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR','CSSD_TECHNICIAN']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to submit a cycle for verification';
  end if;
  if v_cycle.cycle_status <> 'COMPLETED' then
    raise exception 'Cycle must be COMPLETED to submit for verification (current status: %)', v_cycle.cycle_status;
  end if;

  select count(*) into v_evidence_count
  from public.evidence_files
  where entity_type = 'sterilization_cycle' and entity_id = p_cycle_id;

  if v_evidence_count = 0 then
    raise exception 'At least one evidence file must be captured before submitting for verification';
  end if;

  update public.sterilization_cycles
  set cycle_status = 'PENDING_VERIFICATION'
  where id = p_cycle_id
  returning * into v_cycle;

  perform public.log_audit_event(
    v_cycle.organization_id, 'CYCLE_SUBMITTED_FOR_VERIFICATION', 'sterilization_cycle', p_cycle_id,
    null, jsonb_build_object('cycle_status', v_cycle.cycle_status)
  );

  return v_cycle;
end;
$$;

create or replace function public.verify_cycle(
  p_cycle_id uuid,
  p_result public.verification_result,
  p_notes text default null
)
returns public.sterilization_cycles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.sterilization_cycles;
begin
  select * into v_cycle from public.sterilization_cycles where id = p_cycle_id;
  if v_cycle is null then
    raise exception 'Cycle % not found', p_cycle_id;
  end if;
  if v_cycle.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_cycle.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Only a CSSD supervisor or hospital admin can verify a cycle';
  end if;
  if v_cycle.cycle_status <> 'PENDING_VERIFICATION' then
    raise exception 'Cycle must be PENDING_VERIFICATION to verify (current status: %)', v_cycle.cycle_status;
  end if;

  insert into public.verifications (
    organization_id, entity_type, entity_id, verification_type,
    human_result, verified_by, notes
  ) values (
    v_cycle.organization_id, 'sterilization_cycle', p_cycle_id, 'CYCLE_RELEASE',
    p_result, auth.uid(), p_notes
  );

  if p_result = 'PASS' then
    update public.sterilization_cycles set cycle_status = 'PASSED' where id = p_cycle_id returning * into v_cycle;
  elsif p_result = 'FAIL' then
    update public.sterilization_cycles set cycle_status = 'FAILED' where id = p_cycle_id returning * into v_cycle;
    update public.instrument_packs
    set status = 'QUARANTINED'
    where sterilization_cycle_id = p_cycle_id and status = 'PENDING_VERIFICATION';
  end if;
  -- UNDETERMINED: cycle_status stays PENDING_VERIFICATION; the verification
  -- attempt is recorded but always requires a further manual review.

  perform public.log_audit_event(
    v_cycle.organization_id, 'CYCLE_VERIFIED', 'sterilization_cycle', p_cycle_id,
    null, jsonb_build_object('result', p_result, 'cycle_status', v_cycle.cycle_status)
  );

  return v_cycle;
end;
$$;

create or replace function public.release_pack(p_pack_id uuid)
returns public.instrument_packs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pack public.instrument_packs;
  v_cycle public.sterilization_cycles;
begin
  select * into v_pack from public.instrument_packs where id = p_pack_id;
  if v_pack is null then
    raise exception 'Pack % not found', p_pack_id;
  end if;
  if v_pack.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_pack.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR','CSSD_TECHNICIAN']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to release a pack';
  end if;
  if v_pack.status <> 'PENDING_VERIFICATION' then
    raise exception 'Pack must be PENDING_VERIFICATION to release (current status: %)', v_pack.status;
  end if;

  select * into v_cycle from public.sterilization_cycles where id = v_pack.sterilization_cycle_id;
  if v_cycle.cycle_status <> 'PASSED' then
    raise exception 'Cannot release a pack whose cycle has not passed verification (cycle status: %)', v_cycle.cycle_status;
  end if;

  update public.instrument_packs
  set status = 'RELEASED', sterilized_at = coalesce(sterilized_at, now())
  where id = p_pack_id
  returning * into v_pack;

  perform public.log_audit_event(
    v_pack.organization_id, 'PACK_RELEASED', 'instrument_pack', p_pack_id,
    null, jsonb_build_object('pack_status', v_pack.status)
  );

  return v_pack;
end;
$$;

create or replace function public.quarantine_pack(p_pack_id uuid, p_reason text)
returns public.instrument_packs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pack public.instrument_packs;
begin
  select * into v_pack from public.instrument_packs where id = p_pack_id;
  if v_pack is null then
    raise exception 'Pack % not found', p_pack_id;
  end if;
  if v_pack.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_pack.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Only a CSSD supervisor or hospital admin can quarantine a pack';
  end if;
  if v_pack.status not in ('PENDING_VERIFICATION', 'RELEASED') then
    raise exception 'Pack cannot be quarantined from status %', v_pack.status;
  end if;

  update public.instrument_packs
  set status = 'QUARANTINED'
  where id = p_pack_id
  returning * into v_pack;

  perform public.log_audit_event(
    v_pack.organization_id, 'PACK_QUARANTINED', 'instrument_pack', p_pack_id,
    null, jsonb_build_object('pack_status', v_pack.status, 'reason', p_reason)
  );

  return v_pack;
end;
$$;
