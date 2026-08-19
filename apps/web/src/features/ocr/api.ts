import { supabase } from "@/services/supabaseClient";
import type { ExtractedCycleFields, OcrExtraction } from "@/types/database";

export async function listOcrExtractions(evidenceFileId: string): Promise<OcrExtraction[]> {
  const { data, error } = await supabase
    .from("ocr_extractions")
    .select("*")
    .eq("evidence_file_id", evidenceFileId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as OcrExtraction[];
}

export async function requestOcrExtraction(evidenceFileId: string): Promise<OcrExtraction> {
  const { data, error } = await supabase.functions.invoke("ocr-extract", {
    body: { evidence_file_id: evidenceFileId },
  });
  if (error) throw error;
  return data as OcrExtraction;
}

export async function confirmOcrExtraction(
  extractionId: string,
  fields: Partial<ExtractedCycleFields>,
): Promise<OcrExtraction> {
  const { data, error } = await supabase.rpc("confirm_ocr_extraction", {
    p_extraction_id: extractionId,
    p_confirmed_fields: fields,
  });
  if (error) throw error;
  return data as OcrExtraction;
}
