import { useQuery } from "@tanstack/react-query";
import { FileText } from "lucide-react";
import { getEvidenceSignedUrl, listEvidence } from "@/features/evidence/api";
import { OcrPanel } from "@/features/ocr/OcrPanel";
import { AiAnalysisPanel } from "@/features/ai/AiAnalysisPanel";
import { INDICATOR_EVIDENCE_TYPES } from "@/features/ai/api";

export function EvidenceList({ entityType, entityId }: { entityType: string; entityId: string }) {
  const { data: files } = useQuery({
    queryKey: ["evidence", entityType, entityId],
    queryFn: () => listEvidence(entityType, entityId),
  });

  async function openFile(bucket: string, objectPath: string) {
    const url = await getEvidenceSignedUrl(bucket, objectPath);
    window.open(url, "_blank", "noopener,noreferrer");
  }

  if (!files || files.length === 0) {
    return <p className="text-sm text-slate-500">No evidence captured yet.</p>;
  }

  return (
    <ul className="space-y-2">
      {files.map((file) => (
        <li key={file.id}>
          <button
            type="button"
            onClick={() => void openFile(file.bucket, file.object_path)}
            className="flex w-full items-center justify-between rounded-md border border-slate-100 px-3 py-2 text-left text-sm hover:bg-slate-50"
          >
            <span className="flex items-center gap-2">
              <FileText size={14} className="text-slate-400" />
              {file.evidence_type.replace(/_/g, " ")}
            </span>
            <span className="text-xs text-slate-400">{new Date(file.captured_at).toLocaleString()}</span>
          </button>
          {file.evidence_type === "AUTOCLAVE_RECEIPT" && <OcrPanel evidenceFileId={file.id} />}
          {INDICATOR_EVIDENCE_TYPES.includes(file.evidence_type) && <AiAnalysisPanel evidenceFileId={file.id} />}
        </li>
      ))}
    </ul>
  );
}
