-- SteriCord Phase 3: OT point-of-use workflow functions.

create or replace function public.notify_roles(
  p_organization_id uuid,
  p_roles public.user_role[],
  p_priority public.notification_priority,
  p_title text,
  p_body text,
  p_related_entity_type text default null,
  p_related_entity_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  insert into public.notifications (
    organization_id, recipient_user_id, priority, title, body,
    related_entity_type, related_entity_id
  )
  select distinct
    p_organization_id, ur.user_id, p_priority, p_title, p_body,
    p_related_entity_type, p_related_entity_id
  from public.user_roles ur
  join public.profiles p on p.id = ur.user_id and p.is_active
  where ur.organization_id = p_organization_id
    and ur.role = any(p_roles)
    and ur.revoked_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.notify_roles is 'Fans out one notification row per active user currently holding any of the given roles in the organization.';

-- Eligibility check is exposed separately so the client can show a reason
-- before spending time on indicator capture, without yet writing any row.
create or replace function public.check_pack_eligibility(p_pack_id uuid)
returns table (eligible boolean, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pack public.instrument_packs;
begin
  select * into v_pack from public.instrument_packs where id = p_pack_id;

  if v_pack is null then
    return query select false, 'Pack not found';
  elsif v_pack.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    return query select false, 'Not authorized for this organization';
  elsif v_pack.status <> 'RELEASED' then
    return query select false, format('Pack is %s, not RELEASED', v_pack.status);
  elsif v_pack.expiry_date is not null and v_pack.expiry_date < current_date then
    return query select false, format('Pack expired on %s', v_pack.expiry_date);
  else
    return query select true, null::text;
  end if;
end;
$$;

create or replace function public.record_point_of_use_verification(
  p_pack_id uuid,
  p_result public.verification_result,
  p_department_id uuid default null,
  p_patient_reference text default null,
  p_encounter_reference text default null,
  p_notes text default null
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

  select eligible, reason into v_eligible, v_reason from public.check_pack_eligibility(p_pack_id);
  if not v_eligible then
    raise exception 'Pack is not eligible for use: %', v_reason;
  end if;

  insert into public.point_of_use_records (
    organization_id, pack_id, department_id, patient_reference, encounter_reference,
    eligibility_passed, eligibility_reason, verification_result, notes, scanned_by
  ) values (
    v_pack.organization_id, p_pack_id, p_department_id, p_patient_reference, p_encounter_reference,
    true, null, p_result, p_notes, auth.uid()
  )
  returning * into v_record;

  insert into public.verifications (
    organization_id, entity_type, entity_id, verification_type, human_result, verified_by, notes
  ) values (
    v_pack.organization_id, 'instrument_pack', p_pack_id, 'OT_POINT_OF_USE', p_result, auth.uid(), p_notes
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
  -- UNDETERMINED: pack stays RELEASED; the record is kept for follow-up but
  -- nothing is auto-decided, per the human-in-the-loop rule.

  perform public.log_audit_event(
    v_pack.organization_id, 'OT_VERIFICATION_COMPLETED', 'instrument_pack', p_pack_id,
    null, jsonb_build_object('result', p_result, 'point_of_use_record_id', v_record.id)
  );

  return v_record;
end;
$$;

comment on function public.record_point_of_use_verification is 'Sole entry point for OT/ward point-of-use verification. FAIL atomically creates an incident, a quarantine, and CSSD notifications -- never just flips a status flag.';
