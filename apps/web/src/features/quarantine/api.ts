import { supabase } from "@/services/supabaseClient";
import type { Quarantine } from "@/types/database";

export async function listQuarantines(): Promise<Quarantine[]> {
  const { data, error } = await supabase
    .from("quarantines")
    .select("*")
    .order("initiated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as Quarantine[];
}

export async function listQuarantinesByIncident(incidentId: string): Promise<Quarantine[]> {
  const { data, error } = await supabase
    .from("quarantines")
    .select("*")
    .eq("source_incident_id", incidentId);
  if (error) throw error;
  return (data ?? []) as Quarantine[];
}

export async function releaseQuarantine(id: string, releaseReason: string): Promise<Quarantine> {
  const { data, error } = await supabase.rpc("release_quarantine", {
    p_quarantine_id: id,
    p_release_reason: releaseReason,
  });
  if (error) throw error;
  return data as Quarantine;
}
