import { supabase } from "@/services/supabaseClient";
import type { SterilizationCycle, Verification, VerificationResult } from "@/types/database";

export async function listVerifications(entityType: string, entityId: string): Promise<Verification[]> {
  const { data, error } = await supabase
    .from("verifications")
    .select("*")
    .eq("entity_type", entityType)
    .eq("entity_id", entityId)
    .order("verified_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as Verification[];
}

export async function listCycles(): Promise<SterilizationCycle[]> {
  const { data, error } = await supabase
    .from("sterilization_cycles")
    .select("*")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as SterilizationCycle[];
}

export async function getCycle(id: string): Promise<SterilizationCycle> {
  const { data, error } = await supabase.from("sterilization_cycles").select("*").eq("id", id).single();
  if (error) throw error;
  return data as SterilizationCycle;
}

export interface CreateCycleInput {
  organization_id: string;
  equipment_id: string;
  cycle_number: string;
  cycle_type: string;
  operator_user_id: string;
}

export async function createCycle(input: CreateCycleInput): Promise<SterilizationCycle> {
  const { data, error } = await supabase.from("sterilization_cycles").insert(input).select().single();
  if (error) throw error;
  return data as SterilizationCycle;
}

export async function startCycle(cycleId: string): Promise<SterilizationCycle> {
  const { data, error } = await supabase.rpc("start_cycle", { p_cycle_id: cycleId });
  if (error) throw error;
  return data as SterilizationCycle;
}

export async function completeCycle(
  cycleId: string,
  params: { temperature?: number; pressure?: number; holdTimeSeconds?: number },
): Promise<SterilizationCycle> {
  const { data, error } = await supabase.rpc("complete_cycle", {
    p_cycle_id: cycleId,
    p_temperature: params.temperature ?? null,
    p_pressure: params.pressure ?? null,
    p_hold_time_seconds: params.holdTimeSeconds ?? null,
  });
  if (error) throw error;
  return data as SterilizationCycle;
}

export async function submitCycleForVerification(cycleId: string): Promise<SterilizationCycle> {
  const { data, error } = await supabase.rpc("submit_cycle_for_verification", { p_cycle_id: cycleId });
  if (error) throw error;
  return data as SterilizationCycle;
}

export async function verifyCycle(
  cycleId: string,
  result: VerificationResult,
  notes?: string,
): Promise<SterilizationCycle> {
  const { data, error } = await supabase.rpc("verify_cycle", {
    p_cycle_id: cycleId,
    p_result: result,
    p_notes: notes ?? null,
  });
  if (error) throw error;
  return data as SterilizationCycle;
}
