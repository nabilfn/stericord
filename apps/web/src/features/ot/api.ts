import { supabase } from "@/services/supabaseClient";
import type { PointOfUseRecord, VerificationResult } from "@/types/database";

export interface EligibilityResult {
  eligible: boolean;
  reason: string | null;
}

export async function checkPackEligibility(packId: string): Promise<EligibilityResult> {
  const { data, error } = await supabase.rpc("check_pack_eligibility", { p_pack_id: packId });
  if (error) throw error;
  const row = (data as EligibilityResult[])[0];
  return row ?? { eligible: false, reason: "Unknown" };
}

export interface RecordPointOfUseInput {
  packId: string;
  result: VerificationResult;
  departmentId?: string;
  patientReference?: string;
  encounterReference?: string;
  notes?: string;
}

export async function recordPointOfUseVerification(input: RecordPointOfUseInput): Promise<PointOfUseRecord> {
  const { data, error } = await supabase.rpc("record_point_of_use_verification", {
    p_pack_id: input.packId,
    p_result: input.result,
    p_department_id: input.departmentId ?? null,
    p_patient_reference: input.patientReference ?? null,
    p_encounter_reference: input.encounterReference ?? null,
    p_notes: input.notes ?? null,
  });
  if (error) throw error;
  return data as PointOfUseRecord;
}
