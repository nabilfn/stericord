import { supabase } from "@/services/supabaseClient";
import type { Incident, IncidentStatus } from "@/types/database";

export async function listIncidents(): Promise<Incident[]> {
  const { data, error } = await supabase
    .from("incidents")
    .select("*")
    .order("detected_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as Incident[];
}

export async function getIncident(id: string): Promise<Incident> {
  const { data, error } = await supabase.from("incidents").select("*").eq("id", id).single();
  if (error) throw error;
  return data as Incident;
}

export async function acknowledgeIncident(id: string): Promise<Incident> {
  const { data, error } = await supabase.rpc("acknowledge_incident", { p_incident_id: id });
  if (error) throw error;
  return data as Incident;
}

export async function advanceIncidentStatus(id: string, status: IncidentStatus): Promise<Incident> {
  const { data, error } = await supabase.rpc("advance_incident_status", {
    p_incident_id: id,
    p_new_status: status,
  });
  if (error) throw error;
  return data as Incident;
}

export async function resolveIncident(id: string, resolutionNotes: string, close: boolean): Promise<Incident> {
  const { data, error } = await supabase.rpc("resolve_incident", {
    p_incident_id: id,
    p_resolution_notes: resolutionNotes,
    p_close: close,
  });
  if (error) throw error;
  return data as Incident;
}
