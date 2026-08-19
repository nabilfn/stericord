-- SteriCord Phase 2: audit CYCLE_CREATED / PACK_CREATED / EVIDENCE_UPLOADED
-- from triggers, not application code, so a client can't forget to log a
-- compliance-relevant creation event (same reasoning as
-- record_equipment_status_change in Phase 1).

create or replace function public.audit_cycle_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.log_audit_event(
    new.organization_id, 'CYCLE_CREATED', 'sterilization_cycle', new.id,
    null, jsonb_build_object('cycle_number', new.cycle_number, 'equipment_id', new.equipment_id)
  );
  return new;
end;
$$;

create trigger trg_audit_cycle_created
  after insert on public.sterilization_cycles
  for each row execute function public.audit_cycle_created();

create or replace function public.audit_pack_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.log_audit_event(
    new.organization_id, 'PACK_CREATED', 'instrument_pack', new.id,
    null, jsonb_build_object('pack_code', new.pack_code, 'sterilization_cycle_id', new.sterilization_cycle_id)
  );
  return new;
end;
$$;

create trigger trg_audit_pack_created
  after insert on public.instrument_packs
  for each row execute function public.audit_pack_created();

create or replace function public.audit_evidence_uploaded()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.log_audit_event(
    new.organization_id, 'EVIDENCE_UPLOADED', new.entity_type, new.entity_id,
    null, jsonb_build_object('evidence_type', new.evidence_type, 'object_path', new.object_path)
  );
  return new;
end;
$$;

create trigger trg_audit_evidence_uploaded
  after insert on public.evidence_files
  for each row execute function public.audit_evidence_uploaded();
