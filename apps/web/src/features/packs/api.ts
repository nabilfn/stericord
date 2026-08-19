import { supabase } from "@/services/supabaseClient";
import type { InstrumentPack, InstrumentSet } from "@/types/database";

export async function listInstrumentSets(): Promise<InstrumentSet[]> {
  const { data, error } = await supabase
    .from("instrument_sets")
    .select("*")
    .eq("is_active", true)
    .order("name", { ascending: true });
  if (error) throw error;
  return (data ?? []) as InstrumentSet[];
}

export async function listPacksByCycle(cycleId: string): Promise<InstrumentPack[]> {
  const { data, error } = await supabase
    .from("instrument_packs")
    .select("*")
    .eq("sterilization_cycle_id", cycleId)
    .order("pack_code", { ascending: true });
  if (error) throw error;
  return (data ?? []) as InstrumentPack[];
}

export async function getPack(id: string): Promise<InstrumentPack> {
  const { data, error } = await supabase.from("instrument_packs").select("*").eq("id", id).single();
  if (error) throw error;
  return data as InstrumentPack;
}

export async function findPackByCode(code: string): Promise<InstrumentPack | null> {
  const { data, error } = await supabase
    .from("instrument_packs")
    .select("*")
    .or(`pack_code.eq.${code},qr_code.eq.${code}`)
    .maybeSingle();
  if (error) throw error;
  return data as InstrumentPack | null;
}

export interface CreatePackInput {
  organization_id: string;
  instrument_set_id: string;
  sterilization_cycle_id: string;
  pack_code: string;
  expiry_date?: string;
}

export async function createPack(input: CreatePackInput): Promise<InstrumentPack> {
  const { data, error } = await supabase.from("instrument_packs").insert(input).select().single();
  if (error) throw error;
  return data as InstrumentPack;
}

export async function releasePack(packId: string): Promise<InstrumentPack> {
  const { data, error } = await supabase.rpc("release_pack", { p_pack_id: packId });
  if (error) throw error;
  return data as InstrumentPack;
}

export async function quarantinePack(packId: string, reason: string): Promise<InstrumentPack> {
  const { data, error } = await supabase.rpc("quarantine_pack", { p_pack_id: packId, p_reason: reason });
  if (error) throw error;
  return data as InstrumentPack;
}
