-- SteriCord Phase 2: enums for CSSD core workflow.

create type public.cycle_status as enum (
  'CREATED',
  'RUNNING',
  'COMPLETED',
  'PENDING_VERIFICATION',
  'PASSED',
  'FAILED',
  'QUARANTINED'
);

create type public.pack_status as enum (
  'PACKED',
  'STERILIZING',
  'PENDING_VERIFICATION',
  'RELEASED',
  'QUARANTINED',
  'RECALLED',
  'USED',
  'EXPIRED'
);

create type public.evidence_type as enum (
  'AUTOCLAVE_RECEIPT',
  'BOWIE_DICK',
  'BI_TRAY',
  'CHEMICAL_INDICATOR',
  'OT_INDICATOR',
  'WASHER_TEST',
  'GENERAL'
);

create type public.verification_result as enum (
  'PASS',
  'FAIL',
  'UNDETERMINED'
);

alter type public.audit_event_type add value if not exists 'CYCLE_STARTED';
alter type public.audit_event_type add value if not exists 'CYCLE_COMPLETED';
alter type public.audit_event_type add value if not exists 'CYCLE_SUBMITTED_FOR_VERIFICATION';
alter type public.audit_event_type add value if not exists 'PACK_QUARANTINED';
alter type public.audit_event_type add value if not exists 'EVIDENCE_UPLOADED';
