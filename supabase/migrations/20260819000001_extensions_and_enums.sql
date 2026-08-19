-- SteriCord Phase 1: extensions and shared enum types
-- Enum values follow the vocabulary defined in the master development prompt
-- (sections 15, 17, 29) so later phases can extend without renaming.

create extension if not exists "pgcrypto";

create type public.user_role as enum (
  'SYSTEM_ADMIN',
  'HOSPITAL_ADMIN',
  'CSSD_SUPERVISOR',
  'CSSD_TECHNICIAN',
  'OT_NURSE',
  -- reserved for later rollout, see master prompt section 15
  'INFECTION_CONTROL',
  'AUDITOR',
  'BIOMEDICAL_ENGINEER',
  'QUALITY_MANAGER'
);

create type public.equipment_status as enum (
  'ACTIVE',
  'LOCKED_OUT',
  'MAINTENANCE',
  'DECOMMISSIONED'
);

create type public.audit_event_type as enum (
  'USER_LOGIN',
  'USER_LOGOUT',
  'ORGANIZATION_CREATED',
  'ORGANIZATION_UPDATED',
  'DEPARTMENT_CREATED',
  'DEPARTMENT_UPDATED',
  'PROFILE_CREATED',
  'PROFILE_UPDATED',
  'USER_ROLE_GRANTED',
  'USER_ROLE_REVOKED',
  'EQUIPMENT_CREATED',
  'EQUIPMENT_UPDATED',
  'EQUIPMENT_LOCKED',
  'EQUIPMENT_UNLOCKED',
  'EQUIPMENT_STATUS_CHANGED',
  'CYCLE_CREATED',
  'CYCLE_VERIFIED',
  'PACK_CREATED',
  'PACK_RELEASED',
  'PACK_SCANNED',
  'OT_VERIFICATION_COMPLETED',
  'INCIDENT_CREATED',
  'QUARANTINE_STARTED',
  'QUARANTINE_RELEASED',
  'REPORT_EXPORTED'
);
