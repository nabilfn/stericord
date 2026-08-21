-- SteriCord demo/mock data for exploring the mobile (and web) app with a
-- populated pipeline instead of empty states everywhere. Hospital A only
-- (the org every seeded mobile test account belongs to).
--
-- Not part of the automatic `supabase db reset` seed -- Supabase CLI only
-- auto-applies supabase/seed.sql. Run this manually after a reset if you
-- want the demo data back:
--   psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '\"')" -f supabase/seed_demo_data.sql
-- or, from the repo root with the local stack running:
--   PGPASSWORD=postgres psql -h 127.0.0.1 -p 54422 -U postgres -d postgres -f supabase/seed_demo_data.sql

begin;

do $$
declare
  v_org uuid := '00000000-0000-0000-0000-000000000a01';
  v_dept_cssd uuid := '00000000-0000-0000-0000-0000000a0d01';
  v_admin uuid := '00000000-0000-0000-0000-0000000a1001';
  v_supervisor uuid := '00000000-0000-0000-0000-0000000a1002';
  v_technician uuid := '00000000-0000-0000-0000-0000000a1003';
  v_nurse uuid := '00000000-0000-0000-0000-0000000a1004';
  v_equip_autoclave uuid;
  v_set_ortho uuid := '00000000-0000-0000-0000-0000000a2001';
  v_set_minor uuid := '00000000-0000-0000-0000-0000000a2002';

  v_cycle_created uuid;
  v_cycle_running uuid;
  v_cycle_pending uuid;
  v_cycle_passed uuid;
  v_cycle_failed uuid;
  v_cycle_for_ot uuid;

  v_pack_pending_1 uuid;
  v_pack_pending_2 uuid;
  v_pack_released uuid;
  v_pack_used uuid;
  v_pack_quarantined uuid;
  v_pack_for_ot uuid;

  v_evidence_receipt uuid;
  v_evidence_bowiedick_pass uuid;
  v_evidence_bowiedick_undetermined uuid;
  v_evidence_chem_fail uuid;

  v_pou_record uuid;
  v_incident_ot uuid;
  v_incident_old_ack uuid;
  v_incident_old_resolved uuid;
begin
  select id into v_equip_autoclave from public.equipment where organization_id = v_org and equipment_code = 'AUTOCLAVE-A1';

  -- ==========================================================================
  -- Cycle 1: CREATED, no packs yet -- exercises the "Register" empty state
  -- and the Start Cycle action.
  -- ==========================================================================
  insert into public.sterilization_cycles (organization_id, equipment_id, cycle_number, cycle_type, cycle_status, operator_user_id)
  values (v_org, v_equip_autoclave, 'CYC-DEMO-001', 'STEAM', 'CREATED', v_technician)
  returning id into v_cycle_created;

  -- ==========================================================================
  -- Cycle 2: RUNNING -- exercises the Complete Cycle action.
  -- ==========================================================================
  insert into public.sterilization_cycles (organization_id, equipment_id, cycle_number, cycle_type, cycle_status, operator_user_id, started_at)
  values (v_org, v_equip_autoclave, 'CYC-DEMO-002', 'STEAM PREVAC', 'RUNNING', v_technician, now() - interval '20 minutes')
  returning id into v_cycle_running;

  -- ==========================================================================
  -- Cycle 3: PENDING_VERIFICATION with 2 packs, an autoclave receipt (OCR,
  -- confirmed) and a Bowie-Dick indicator (AI suggests PASS, HIGH confidence)
  -- -- exercises the Verify Cycle sheet with a real AI banner.
  -- ==========================================================================
  insert into public.sterilization_cycles (
    organization_id, equipment_id, cycle_number, cycle_type, cycle_status, operator_user_id,
    started_at, completed_at, temperature, pressure, hold_time_seconds
  ) values (
    v_org, v_equip_autoclave, 'CYC-DEMO-003', 'STEAM PREVAC', 'CREATED', v_technician,
    now() - interval '2 hours', now() - interval '90 minutes', 134.0, 2.1, 210
  ) returning id into v_cycle_pending;

  insert into public.instrument_packs (organization_id, instrument_set_id, sterilization_cycle_id, pack_code, status, created_by)
  values (v_org, v_set_ortho, v_cycle_pending, 'PK-DEMO-101', 'PACKED', v_technician)
  returning id into v_pack_pending_1;
  insert into public.instrument_packs (organization_id, instrument_set_id, sterilization_cycle_id, pack_code, status, created_by)
  values (v_org, v_set_minor, v_cycle_pending, 'PK-DEMO-102', 'PACKED', v_technician)
  returning id into v_pack_pending_2;

  update public.sterilization_cycles set cycle_status = 'PENDING_VERIFICATION' where id = v_cycle_pending;
  update public.instrument_packs set status = 'PENDING_VERIFICATION' where sterilization_cycle_id = v_cycle_pending;

  insert into public.evidence_files (
    organization_id, entity_type, entity_id, object_path, evidence_type, captured_by,
    captured_at, quality_status, blur_score, brightness_score, glare_ratio, retention_expires_at
  ) values (
    v_org, 'sterilization_cycle', v_cycle_pending, v_org || '/sterilization_cycle/' || v_cycle_pending || '/demo-receipt.jpg',
    'AUTOCLAVE_RECEIPT', v_technician, now() - interval '95 minutes', 'ACCEPTED', 145.0, 0.62, 0.02,
    now() + interval '7 years'
  ) returning id into v_evidence_receipt;

  insert into public.ocr_extractions (
    organization_id, evidence_file_id, status, extracted_fields, confidence,
    human_confirmed_fields, confirmed_by, confirmed_at, requested_by
  ) values (
    v_org, v_evidence_receipt, 'COMPLETED',
    jsonb_build_object('cycle_number', 'CYC-DEMO-003', 'temperature', 134.0, 'pressure', 2.1, 'hold_time_seconds', 210, 'result', 'PASS'),
    0.93,
    jsonb_build_object('cycle_number', 'CYC-DEMO-003', 'temperature', 134.0, 'pressure', 2.1, 'hold_time_seconds', 210, 'result', 'PASS'),
    v_technician, now() - interval '80 minutes', v_technician
  );

  insert into public.evidence_files (
    organization_id, entity_type, entity_id, object_path, evidence_type, captured_by,
    captured_at, quality_status, blur_score, brightness_score, glare_ratio, retention_expires_at
  ) values (
    v_org, 'sterilization_cycle', v_cycle_pending, v_org || '/sterilization_cycle/' || v_cycle_pending || '/demo-bowiedick.jpg',
    'BOWIE_DICK', v_technician, now() - interval '92 minutes', 'ACCEPTED', 152.0, 0.58, 0.01,
    now() + interval '7 years'
  ) returning id into v_evidence_bowiedick_pass;

  insert into public.ai_analyses (
    organization_id, evidence_file_id, status, indicator_type, suggested_result, confidence, confidence_band, observations, requested_by
  ) values (
    v_org, v_evidence_bowiedick_pass, 'COMPLETED', 'BOWIE_DICK', 'PASS', 0.96, 'HIGH',
    array['Uniform colour transition across the indicator', 'No obvious incomplete region', 'Indicator fully visible in frame'],
    v_technician
  );

  -- ==========================================================================
  -- Cycle 4: PASSED -- one pack RELEASED, one pack USED (with a real
  -- point-of-use record) -- exercises Cycle Detail's "no action" state and
  -- Pack Detail's release history.
  -- ==========================================================================
  insert into public.sterilization_cycles (
    organization_id, equipment_id, cycle_number, cycle_type, cycle_status, operator_user_id,
    started_at, completed_at, temperature, pressure, hold_time_seconds
  ) values (
    v_org, v_equip_autoclave, 'CYC-DEMO-004', 'STEAM PREVAC', 'CREATED', v_technician,
    now() - interval '1 day', now() - interval '1 day' + interval '40 minutes', 134.0, 2.15, 210
  ) returning id into v_cycle_passed;

  insert into public.instrument_packs (organization_id, instrument_set_id, sterilization_cycle_id, pack_code, status, created_by, expiry_date)
  values (v_org, v_set_ortho, v_cycle_passed, 'PK-DEMO-201', 'PACKED', v_technician, current_date + interval '6 months')
  returning id into v_pack_released;
  insert into public.instrument_packs (organization_id, instrument_set_id, sterilization_cycle_id, pack_code, status, created_by, expiry_date)
  values (v_org, v_set_minor, v_cycle_passed, 'PK-DEMO-202', 'PACKED', v_technician, current_date + interval '6 months')
  returning id into v_pack_used;

  update public.sterilization_cycles set cycle_status = 'PASSED' where id = v_cycle_passed;
  update public.instrument_packs set status = 'RELEASED' where sterilization_cycle_id = v_cycle_passed;

  insert into public.verifications (organization_id, entity_type, entity_id, verification_type, human_result, verified_by, verified_at, notes)
  values (v_org, 'sterilization_cycle', v_cycle_passed, 'CYCLE_RELEASE', 'PASS', v_supervisor, now() - interval '1 day' + interval '50 minutes', 'All parameters within spec.');

  update public.instrument_packs set status = 'USED' where id = v_pack_used;
  insert into public.point_of_use_records (
    organization_id, pack_id, department_id, eligibility_passed, verification_result, notes, scanned_by, scanned_at
  ) values (
    v_org, v_pack_used, v_dept_cssd, true, 'PASS', 'Used in scheduled procedure.', v_nurse, now() - interval '3 hours'
  ) returning id into v_pou_record;

  insert into public.verifications (organization_id, entity_type, entity_id, verification_type, human_result, verified_by, verified_at)
  values (v_org, 'instrument_pack', v_pack_used, 'OT_POINT_OF_USE', 'PASS', v_nurse, now() - interval '3 hours');

  -- ==========================================================================
  -- Cycle 5: FAILED -- pack auto-quarantined by verify_cycle's own logic,
  -- with a chemical-indicator evidence photo where AI suggests FAIL (a real
  -- confident failure, not a low-confidence UNDETERMINED) -- exercises the
  -- serious/critical AI-result treatment.
  -- ==========================================================================
  insert into public.sterilization_cycles (
    organization_id, equipment_id, cycle_number, cycle_type, cycle_status, operator_user_id,
    started_at, completed_at, temperature, pressure, hold_time_seconds
  ) values (
    v_org, v_equip_autoclave, 'CYC-DEMO-005', 'STEAM PREVAC', 'CREATED', v_technician,
    now() - interval '5 hours', now() - interval '4 hours', 118.0, 1.4, 90
  ) returning id into v_cycle_failed;

  insert into public.instrument_packs (organization_id, instrument_set_id, sterilization_cycle_id, pack_code, status, created_by)
  values (v_org, v_set_minor, v_cycle_failed, 'PK-DEMO-301', 'PACKED', v_technician)
  returning id into v_pack_quarantined;

  update public.sterilization_cycles set cycle_status = 'PENDING_VERIFICATION' where id = v_cycle_failed;
  update public.instrument_packs set status = 'PENDING_VERIFICATION' where id = v_pack_quarantined;

  insert into public.evidence_files (
    organization_id, entity_type, entity_id, object_path, evidence_type, captured_by,
    captured_at, quality_status, blur_score, brightness_score, glare_ratio, retention_expires_at
  ) values (
    v_org, 'sterilization_cycle', v_cycle_failed, v_org || '/sterilization_cycle/' || v_cycle_failed || '/demo-chemind.jpg',
    'CHEMICAL_INDICATOR', v_technician, now() - interval '4 hours 10 minutes', 'ACCEPTED', 138.0, 0.51, 0.03,
    now() + interval '7 years'
  ) returning id into v_evidence_chem_fail;

  insert into public.ai_analyses (
    organization_id, evidence_file_id, status, indicator_type, suggested_result, confidence, confidence_band, observations, requested_by
  ) values (
    v_org, v_evidence_chem_fail, 'COMPLETED', 'CHEMICAL_INDICATOR', 'FAIL', 0.91, 'HIGH',
    array['Colour change incomplete across indicator strip', 'Parameters below required temperature threshold'],
    v_technician
  );

  -- A second, LOW-confidence indicator photo forced to UNDETERMINED --
  -- exercises the "Manual review required" AI state specifically.
  insert into public.evidence_files (
    organization_id, entity_type, entity_id, object_path, evidence_type, captured_by,
    captured_at, quality_status, blur_score, brightness_score, glare_ratio, retention_expires_at
  ) values (
    v_org, 'sterilization_cycle', v_cycle_failed, v_org || '/sterilization_cycle/' || v_cycle_failed || '/demo-bowiedick-low.jpg',
    'BOWIE_DICK', v_technician, now() - interval '4 hours 5 minutes', 'ACCEPTED', 91.0, 0.40, 0.11,
    now() + interval '7 years'
  ) returning id into v_evidence_bowiedick_undetermined;

  insert into public.ai_analyses (
    organization_id, evidence_file_id, status, indicator_type, suggested_result, confidence, confidence_band, observations, requested_by
  ) values (
    v_org, v_evidence_bowiedick_undetermined, 'COMPLETED', 'BOWIE_DICK', 'UNDETERMINED', 0.38, 'LOW',
    array['Glare obscures part of the indicator', 'Confidence below threshold for an automated suggestion'],
    v_technician
  );

  update public.sterilization_cycles set cycle_status = 'FAILED' where id = v_cycle_failed;
  update public.instrument_packs set status = 'QUARANTINED' where id = v_pack_quarantined;

  insert into public.verifications (organization_id, entity_type, entity_id, verification_type, ai_suggested_result, ai_confidence, human_result, verified_by, verified_at, notes)
  values (v_org, 'sterilization_cycle', v_cycle_failed, 'CYCLE_RELEASE', 'FAIL', 0.91, 'FAIL', v_supervisor, now() - interval '3 hours 50 minutes', 'Chemical indicator failed -- cycle rejected, pack quarantined.');

  -- ==========================================================================
  -- OT point-of-use failure -- the real path that creates an incident +
  -- quarantine + CRITICAL notifications, run through the same logic
  -- record_point_of_use_verification uses (mirrored here directly since
  -- this is a superuser seed script, not an authenticated RPC call).
  -- ==========================================================================
  insert into public.sterilization_cycles (
    organization_id, equipment_id, cycle_number, cycle_type, cycle_status, operator_user_id,
    started_at, completed_at, temperature, pressure, hold_time_seconds
  ) values (
    v_org, v_equip_autoclave, 'CYC-DEMO-006', 'STEAM PREVAC', 'CREATED', v_technician,
    now() - interval '6 hours', now() - interval '5 hours 20 minutes', 134.0, 2.1, 210
  ) returning id into v_cycle_for_ot;

  insert into public.instrument_packs (organization_id, instrument_set_id, sterilization_cycle_id, pack_code, status, created_by, expiry_date)
  values (v_org, v_set_ortho, v_cycle_for_ot, 'PK-DEMO-401', 'PACKED', v_technician, current_date + interval '6 months')
  returning id into v_pack_for_ot;

  update public.sterilization_cycles set cycle_status = 'PASSED' where id = v_cycle_for_ot;
  update public.instrument_packs set status = 'RELEASED' where id = v_pack_for_ot;

  update public.instrument_packs set status = 'QUARANTINED' where id = v_pack_for_ot;
  insert into public.point_of_use_records (
    organization_id, pack_id, department_id, eligibility_passed, verification_result, notes, scanned_by, scanned_at
  ) values (
    v_org, v_pack_for_ot, v_dept_cssd, true, 'FAIL', 'Indicator failed at point of use.', v_nurse, now() - interval '25 minutes'
  ) returning id into v_pou_record;

  insert into public.incidents (
    organization_id, source_type, related_entity_type, related_entity_id, point_of_use_record_id,
    status, priority, description, detected_by, detected_at
  ) values (
    v_org, 'OT_VERIFICATION_FAILURE', 'instrument_pack', v_pack_for_ot, v_pou_record,
    'ALERTED', 'CRITICAL', 'OT point-of-use verification failed for pack PK-DEMO-401', v_nurse, now() - interval '25 minutes'
  ) returning id into v_incident_ot;

  insert into public.quarantines (organization_id, source_incident_id, scope_type, scope_id, reason, initiated_by, initiated_at)
  values (v_org, v_incident_ot, 'PACK', v_pack_for_ot, 'OT point-of-use verification failure', v_nurse, now() - interval '25 minutes');

  -- ==========================================================================
  -- Two older incidents at different lifecycle stages, for variety.
  -- ==========================================================================
  insert into public.incidents (organization_id, source_type, related_entity_type, related_entity_id, status, priority, description, detected_by, detected_at, acknowledged_by, acknowledged_at)
  values (v_org, 'OT_VERIFICATION_FAILURE', 'instrument_pack', v_pack_quarantined, 'ACKNOWLEDGED', 'HIGH', 'Chemical indicator out of spec, flagged during CSSD verification.', v_technician, now() - interval '2 days', v_supervisor, now() - interval '2 days' + interval '15 minutes')
  returning id into v_incident_old_ack;

  insert into public.incidents (organization_id, source_type, related_entity_type, related_entity_id, status, priority, description, detected_by, detected_at, acknowledged_by, acknowledged_at, resolved_by, resolved_at, resolution_notes)
  values (v_org, 'EQUIPMENT_FAULT', 'equipment', v_equip_autoclave, 'RESOLVED', 'MEDIUM', 'Autoclave door seal replaced after a minor leak was noticed during routine checks.', v_technician, now() - interval '5 days', v_supervisor, now() - interval '5 days' + interval '1 hour', v_supervisor, now() - interval '4 days', 'Seal replaced and equipment re-qualified. Returned to ACTIVE status.')
  returning id into v_incident_old_resolved;

  -- ==========================================================================
  -- Notifications -- a spread across Critical/Today/Earlier and read/unread,
  -- to both admin and supervisor (the roles that receive incident alerts).
  -- ==========================================================================
  insert into public.notifications (organization_id, recipient_user_id, priority, title, body, related_entity_type, related_entity_id, is_read, created_at) values
    (v_org, v_admin, 'CRITICAL', 'OT verification failed: PK-DEMO-401', 'Pack quarantined pending investigation.', 'instrument_pack', v_pack_for_ot, false, now() - interval '25 minutes'),
    (v_org, v_supervisor, 'CRITICAL', 'OT verification failed: PK-DEMO-401', 'Pack quarantined pending investigation.', 'instrument_pack', v_pack_for_ot, false, now() - interval '25 minutes'),
    (v_org, v_supervisor, 'HIGH', 'Cycle CYC-DEMO-005 failed verification', 'Chemical indicator failed -- pack quarantined.', 'sterilization_cycle', v_cycle_failed, false, now() - interval '3 hours 50 minutes'),
    (v_org, v_admin, 'MEDIUM', 'Cycle CYC-DEMO-003 pending verification', 'Two packs ready for review.', 'sterilization_cycle', v_cycle_pending, true, now() - interval '90 minutes'),
    (v_org, v_supervisor, 'HIGH', 'Incident acknowledged', 'You acknowledged the chemical indicator incident.', 'incident', v_incident_old_ack, true, now() - interval '2 days' + interval '15 minutes'),
    (v_org, v_admin, 'MEDIUM', 'Equipment incident resolved', 'AUTOCLAVE-A1 door seal incident marked resolved.', 'incident', v_incident_old_resolved, true, now() - interval '4 days');
end $$;

commit;
