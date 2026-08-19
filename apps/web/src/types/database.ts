/**
 * Hand-written types mirroring the Phase 1 schema in supabase/migrations.
 * Regenerate/replace with `supabase gen types typescript` once the schema
 * stabilizes; keep field names in sync with the migrations in the meantime.
 */

export type UserRole =
  | "SYSTEM_ADMIN"
  | "HOSPITAL_ADMIN"
  | "CSSD_SUPERVISOR"
  | "CSSD_TECHNICIAN"
  | "OT_NURSE"
  | "INFECTION_CONTROL"
  | "AUDITOR"
  | "BIOMEDICAL_ENGINEER"
  | "QUALITY_MANAGER";

export type EquipmentStatus = "ACTIVE" | "LOCKED_OUT" | "MAINTENANCE" | "DECOMMISSIONED";

export type EquipmentType =
  | "STEAM_AUTOCLAVE"
  | "ETO_STERILIZER"
  | "PLASMA_STERILIZER"
  | "WASHER_DISINFECTOR"
  | "ULTRASONIC_CLEANER"
  | "OTHER";

export interface Organization {
  id: string;
  name: string;
  slug: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Department {
  id: string;
  organization_id: string;
  name: string;
  code: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Profile {
  id: string;
  organization_id: string;
  department_id: string | null;
  full_name: string;
  email: string;
  phone: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserRoleGrant {
  id: string;
  user_id: string;
  organization_id: string;
  role: UserRole;
  granted_by: string | null;
  granted_at: string;
  revoked_by: string | null;
  revoked_at: string | null;
}

export interface Equipment {
  id: string;
  organization_id: string;
  department_id: string | null;
  equipment_code: string;
  equipment_type: EquipmentType;
  manufacturer: string | null;
  model_name: string | null;
  serial_number: string | null;
  location: string | null;
  operating_status: EquipmentStatus;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface EquipmentStatusEvent {
  id: string;
  organization_id: string;
  equipment_id: string;
  previous_status: EquipmentStatus | null;
  new_status: EquipmentStatus;
  reason: string | null;
  changed_by: string | null;
  changed_at: string;
}

export interface AuditEvent {
  id: string;
  organization_id: string;
  actor_user_id: string | null;
  event_type: string;
  entity_type: string;
  entity_id: string | null;
  previous_state: Record<string, unknown> | null;
  new_state: Record<string, unknown> | null;
  occurred_at: string;
  session_id: string | null;
  device_id: string | null;
  metadata: Record<string, unknown> | null;
  event_hash: string;
  previous_event_hash: string | null;
}
