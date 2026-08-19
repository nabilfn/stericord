import { supabase } from "@/services/supabaseClient";
import { storageProvider } from "@/services/storageProvider";
import type { EvidenceFile, EvidenceType } from "@/types/database";

const BUCKET = "evidence";

export async function listEvidence(entityType: string, entityId: string): Promise<EvidenceFile[]> {
  const { data, error } = await supabase
    .from("evidence_files")
    .select("*")
    .eq("entity_type", entityType)
    .eq("entity_id", entityId)
    .order("captured_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as EvidenceFile[];
}

export interface UploadEvidenceInput {
  organizationId: string;
  entityType: string;
  entityId: string;
  evidenceType: EvidenceType;
  file: File;
  capturedBy: string;
}

export async function uploadEvidence(input: UploadEvidenceInput): Promise<EvidenceFile> {
  const { organizationId, entityType, entityId, evidenceType, file, capturedBy } = input;
  const objectPath = `${organizationId}/${entityType}/${entityId}/${Date.now()}-${file.name}`;

  const [hash] = await Promise.all([
    storageProvider.calculateHash(file),
    storageProvider.uploadEvidence(BUCKET, objectPath, file),
  ]);

  const { data, error } = await supabase
    .from("evidence_files")
    .insert({
      organization_id: organizationId,
      entity_type: entityType,
      entity_id: entityId,
      bucket: BUCKET,
      object_path: objectPath,
      file_type: file.type.split("/")[1] ?? null,
      mime_type: file.type,
      file_size: file.size,
      sha256_hash: hash,
      evidence_type: evidenceType,
      captured_by: capturedBy,
    })
    .select()
    .single();
  if (error) throw error;
  return data as EvidenceFile;
}

export async function getEvidenceSignedUrl(bucket: string, objectPath: string): Promise<string> {
  return storageProvider.generateSignedUrl(bucket, objectPath, 60 * 5);
}
