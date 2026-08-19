import { supabase } from "@/services/supabaseClient";
import type { AiAnalysis, EvidenceType } from "@/types/database";

export const INDICATOR_EVIDENCE_TYPES: EvidenceType[] = [
  "BOWIE_DICK",
  "CHEMICAL_INDICATOR",
  "BI_TRAY",
  "OT_INDICATOR",
  "WASHER_TEST",
];

export async function listAiAnalyses(evidenceFileId: string): Promise<AiAnalysis[]> {
  const { data, error } = await supabase
    .from("ai_analyses")
    .select("*")
    .eq("evidence_file_id", evidenceFileId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as AiAnalysis[];
}

export async function requestAiAnalysis(evidenceFileId: string): Promise<AiAnalysis> {
  const { data, error } = await supabase.functions.invoke("gemini-analyze", {
    body: { evidence_file_id: evidenceFileId },
  });
  if (error) throw error;
  return data as AiAnalysis;
}

/** Most recent AI analysis of any indicator-type evidence attached to a cycle/pack, for pre-filling the verification form. */
export async function getLatestIndicatorAnalysis(entityType: string, entityId: string): Promise<AiAnalysis | null> {
  const { data: files, error: filesError } = await supabase
    .from("evidence_files")
    .select("id")
    .eq("entity_type", entityType)
    .eq("entity_id", entityId)
    .in("evidence_type", INDICATOR_EVIDENCE_TYPES);
  if (filesError) throw filesError;
  if (!files || files.length === 0) return null;

  const { data, error } = await supabase
    .from("ai_analyses")
    .select("*")
    .in(
      "evidence_file_id",
      files.map((f) => f.id),
    )
    .eq("status", "COMPLETED")
    .order("created_at", { ascending: false })
    .limit(1);
  if (error) throw error;
  return (data?.[0] as AiAnalysis) ?? null;
}
