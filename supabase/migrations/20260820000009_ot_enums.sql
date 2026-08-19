-- SteriCord Phase 3: enums for OT point-of-use safety.

create type public.incident_status as enum (
  'DETECTED',
  'ALERTED',
  'ACKNOWLEDGED',
  'REPLACEMENT_DISPATCHED',
  'REPLACEMENT_RECEIVED',
  'QUARANTINE_IN_PROGRESS',
  'NCR_OPEN',
  'RESOLVED',
  'CLOSED'
);

create type public.incident_priority as enum ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

create type public.quarantine_scope as enum ('PACK', 'CYCLE', 'BATCH', 'EQUIPMENT_RELATED_GROUP');

create type public.quarantine_status as enum ('ACTIVE', 'RELEASED');

create type public.notification_priority as enum ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
