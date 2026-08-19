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

export type CycleStatus =
  | "CREATED"
  | "RUNNING"
  | "COMPLETED"
  | "PENDING_VERIFICATION"
  | "PASSED"
  | "FAILED"
  | "QUARANTINED";

export type PackStatus =
  | "PACKED"
  | "STERILIZING"
  | "PENDING_VERIFICATION"
  | "RELEASED"
  | "QUARANTINED"
  | "RECALLED"
  | "USED"
  | "EXPIRED";

export type EvidenceType =
  | "AUTOCLAVE_RECEIPT"
  | "BOWIE_DICK"
  | "BI_TRAY"
  | "CHEMICAL_INDICATOR"
  | "OT_INDICATOR"
  | "WASHER_TEST"
  | "GENERAL";

export type VerificationResult = "PASS" | "FAIL" | "UNDETERMINED";

export interface InstrumentSet {
  id: string;
  organization_id: string;
  name: string;
  code: string;
  description: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface SterilizationCycle {
  id: string;
  organization_id: string;
  equipment_id: string;
  cycle_number: string;
  cycle_type: string;
  started_at: string | null;
  completed_at: string | null;
  temperature: number | null;
  pressure: number | null;
  hold_time_seconds: number | null;
  operator_user_id: string | null;
  cycle_status: CycleStatus;
  created_at: string;
  updated_at: string;
}

export interface InstrumentPack {
  id: string;
  organization_id: string;
  instrument_set_id: string;
  sterilization_cycle_id: string;
  pack_code: string;
  qr_code: string;
  packed_at: string;
  sterilized_at: string | null;
  expiry_date: string | null;
  status: PackStatus;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export type EvidenceQualityStatus = "ACCEPTED" | "RETAKE_REQUIRED";
export type EvidenceQualityReason =
  | "IMAGE_TOO_BLURRY"
  | "IMAGE_TOO_DARK"
  | "GLARE_DETECTED"
  | "INDICATOR_NOT_IN_FRAME";

export interface EvidenceFile {
  id: string;
  organization_id: string;
  entity_type: string;
  entity_id: string;
  storage_provider: string;
  bucket: string;
  object_path: string;
  file_type: string | null;
  mime_type: string | null;
  file_size: number | null;
  sha256_hash: string | null;
  evidence_type: EvidenceType;
  captured_by: string | null;
  captured_at: string;
  created_at: string;
  quality_status: EvidenceQualityStatus | null;
  quality_reasons: EvidenceQualityReason[];
  blur_score: number | null;
  brightness_score: number | null;
  glare_ratio: number | null;
}

export interface Verification {
  id: string;
  organization_id: string;
  entity_type: string;
  entity_id: string;
  verification_type: string;
  ai_suggested_result: VerificationResult | null;
  ai_confidence: number | null;
  human_result: VerificationResult;
  verified_by: string;
  verified_at: string;
  notes: string | null;
  created_at: string;
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

export interface PointOfUseRecord {
  id: string;
  organization_id: string;
  pack_id: string;
  department_id: string | null;
  patient_reference: string | null;
  encounter_reference: string | null;
  eligibility_passed: boolean;
  eligibility_reason: string | null;
  verification_result: VerificationResult;
  notes: string | null;
  scanned_by: string;
  scanned_at: string;
  created_at: string;
}

export type IncidentStatus =
  | "DETECTED"
  | "ALERTED"
  | "ACKNOWLEDGED"
  | "REPLACEMENT_DISPATCHED"
  | "REPLACEMENT_RECEIVED"
  | "QUARANTINE_IN_PROGRESS"
  | "NCR_OPEN"
  | "RESOLVED"
  | "CLOSED";

export type IncidentPriority = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";

export interface Incident {
  id: string;
  organization_id: string;
  source_type: string;
  related_entity_type: string;
  related_entity_id: string | null;
  point_of_use_record_id: string | null;
  status: IncidentStatus;
  priority: IncidentPriority;
  description: string | null;
  detected_by: string | null;
  detected_at: string;
  acknowledged_by: string | null;
  acknowledged_at: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  resolution_notes: string | null;
  created_at: string;
  updated_at: string;
}

export type QuarantineScope = "PACK" | "CYCLE" | "BATCH" | "EQUIPMENT_RELATED_GROUP";
export type QuarantineStatus = "ACTIVE" | "RELEASED";

export interface Quarantine {
  id: string;
  organization_id: string;
  source_incident_id: string | null;
  scope_type: QuarantineScope;
  scope_id: string;
  reason: string;
  status: QuarantineStatus;
  initiated_by: string | null;
  initiated_at: string;
  released_by: string | null;
  released_at: string | null;
  release_reason: string | null;
}

export type NotificationPriority = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";

export interface AppNotification {
  id: string;
  organization_id: string;
  recipient_user_id: string;
  channel: string;
  priority: NotificationPriority;
  title: string;
  body: string | null;
  related_entity_type: string | null;
  related_entity_id: string | null;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}
