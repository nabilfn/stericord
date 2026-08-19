-- SteriCord Phase 6: multimodal AI (Gemini) indicator analysis.
-- Master prompt section 35 (AIProvider / AIAnalysisResult shape), section
-- 36 (confidence routing -- "never force uncertain AI into PASS or FAIL"),
-- section 38 (AI may assist/classify/recommend/flag; it may never
-- autonomously release a pack or declare a result).
--
-- ai_analyses.suggested_result is already confidence-forced by the
-- gemini-analyze edge function itself (a LOW-confidence response is
-- rewritten to UNDETERMINED before it's ever stored) -- so even a client
-- bug can't surface a confident-looking PASS/FAIL from a low-confidence
-- read. This table is purely advisory; verifications.human_result (Phase 2)
-- remains the only authoritative outcome.

create type public.ai_confidence_band as enum ('HIGH', 'MEDIUM', 'LOW');
create type public.ai_analysis_status as enum ('COMPLETED', 'FAILED', 'NOT_CONFIGURED');

alter type public.audit_event_type add value if not exists 'AI_ANALYSIS_REQUESTED';
alter type public.audit_event_type add value if not exists 'AI_ANALYSIS_COMPLETED';

create table public.ai_analyses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  evidence_file_id uuid not null references public.evidence_files(id) on delete cascade,
  provider text not null default 'gemini',
  model text,
  status public.ai_analysis_status not null,
  indicator_type public.evidence_type,
  suggested_result public.verification_result,
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),
  confidence_band public.ai_confidence_band,
  observations text[] not null default '{}',
  raw_response jsonb,
  error_message text,
  requested_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.ai_analyses is 'Advisory Gemini classification of one indicator photo. suggested_result/confidence are never authoritative -- see verifications.human_result. Rows are written only by the gemini-analyze edge function.';

create index idx_ai_analyses_organization_id on public.ai_analyses(organization_id);
create index idx_ai_analyses_evidence_file_id on public.ai_analyses(evidence_file_id);

alter table public.ai_analyses enable row level security;

create policy ai_analyses_select on public.ai_analyses
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

-- Link an AI analysis to the human verification it informed, for Phase 37's
-- "collect labelled data from the start" -- purely additive: existing
-- callers that omit p_ai_analysis_id get identical behavior to before.

-- CREATE OR REPLACE does not substitute for a DROP when the parameter list
-- changes -- Postgres identifies a function by name AND argument types, so
-- adding a parameter here would otherwise create a second, overloaded
-- verify_cycle instead of replacing the Phase 2 one, leaving every existing
-- 3-argument call ambiguous ("function ... is not unique"). Drop the exact
-- old signature first.
drop function if exists public.verify_cycle(uuid, public.verification_result, text);

create or replace function public.verify_cycle(
  p_cycle_id uuid,
  p_result public.verification_result,
  p_notes text default null,
  p_ai_analysis_id uuid default null
)
returns public.sterilization_cycles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.sterilization_cycles;
  v_ai_result public.verification_result;
  v_ai_confidence numeric;
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

  if p_ai_analysis_id is not null then
    select suggested_result, confidence into v_ai_result, v_ai_confidence
    from public.ai_analyses
    where id = p_ai_analysis_id and organization_id = v_cycle.organization_id;
  end if;

  insert into public.verifications (
    organization_id, entity_type, entity_id, verification_type,
    ai_suggested_result, ai_confidence, human_result, verified_by, notes
  ) values (
    v_cycle.organization_id, 'sterilization_cycle', p_cycle_id, 'CYCLE_RELEASE',
    v_ai_result, v_ai_confidence, p_result, auth.uid(), p_notes
  );

  if p_result = 'PASS' then
    update public.sterilization_cycles set cycle_status = 'PASSED' where id = p_cycle_id returning * into v_cycle;
  elsif p_result = 'FAIL' then
    update public.sterilization_cycles set cycle_status = 'FAILED' where id = p_cycle_id returning * into v_cycle;
    update public.instrument_packs
    set status = 'QUARANTINED'
    where sterilization_cycle_id = p_cycle_id and status = 'PENDING_VERIFICATION';
  end if;

  perform public.log_audit_event(
    v_cycle.organization_id, 'CYCLE_VERIFIED', 'sterilization_cycle', p_cycle_id,
    null, jsonb_build_object('result', p_result, 'cycle_status', v_cycle.cycle_status, 'ai_analysis_id', p_ai_analysis_id)
  );

  return v_cycle;
end;
$$;

-- Same reasoning as verify_cycle above: drop the exact Phase 3 signature
-- before adding a parameter, or it becomes an ambiguous overload instead of
-- a replacement.
drop function if exists public.record_point_of_use_verification(uuid, public.verification_result, uuid, text, text, text);

create or replace function public.record_point_of_use_verification(
  p_pack_id uuid,
  p_result public.verification_result,
  p_department_id uuid default null,
  p_patient_reference text default null,
  p_encounter_reference text default null,
  p_notes text default null,
  p_ai_analysis_id uuid default null
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
