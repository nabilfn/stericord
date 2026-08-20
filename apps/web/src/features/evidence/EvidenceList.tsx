import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { FileText, FileDown } from "lucide-react";
import { getEvidenceSignedUrl, listEvidence } from "@/features/evidence/api";
import { OcrPanel } from "@/features/ocr/OcrPanel";
import { AiAnalysisPanel } from "@/features/ai/AiAnalysisPanel";
import { INDICATOR_EVIDENCE_TYPES } from "@/features/ai/api";
import { downloadReport } from "@/features/reports/api";

export function EvidenceList({ entityType, entityId }: { entityType: string; entityId: string }) {
  const [downloadingId, setDownloadingId] = useState<string | null>(null);
  const { data: files } = useQuery({
    queryKey: ["evidence", entityType, entityId],
    queryFn: () => listEvidence(entityType, entityId),
  });

  async function openFile(bucket: string, objectPath: string) {
    const url = await getEvidenceSignedUrl(bucket, objectPath);
    window.open(url, "_blank", "noopener,noreferrer");
  }

  async function downloadSheet(evidenceId: string, evidenceType: string) {
    setDownloadingId(evidenceId);
    try {
      await downloadReport("evidence", evidenceId, `evidence-sheet-${evidenceType}-${evidenceId.slice(0, 8)}`);
    } catch {
      // Reporting service may not be running locally -- non-fatal, evidence stays viewable either way.
    } finally {
      setDownloadingId(null);
    }
  }

  if (!files || files.length === 0) {
    return <p className="text-sm text-slate-500">No evidence captured yet.</p>;
  }

  return (
    <ul className="space-y-2">
      {files.map((file) => (
        <li key={file.id}>
          <div className="flex w-full items-center justify-between rounded-md border border-slate-100 px-3 py-2 text-sm hover:bg-slate-50">
            <button
              type="button"
              onClick={() => void openFile(file.bucket, file.object_path)}
              className="flex flex-1 items-center gap-2 text-left"
            >
              <FileText size={14} className="text-slate-400" />
              {file.evidence_type.replace(/_/g, " ")}
              <span className="text-xs text-slate-400">{new Date(file.captured_at).toLocaleString()}</span>
            </button>
            <button
              type="button"
              title="Download evidence sheet PDF"
              disabled={downloadingId === file.id}
              onClick={() => void downloadSheet(file.id, file.evidence_type)}
              className="ml-2 rounded p-1 text-slate-400 hover:bg-slate-100 hover:text-slate-600 disabled:opacity-50"
            >
              <FileDown size={14} />
            </button>
          </div>
          {file.evidence_type === "AUTOCLAVE_RECEIPT" && <OcrPanel evidenceFileId={file.id} />}
          {INDICATOR_EVIDENCE_TYPES.includes(file.evidence_type) && <AiAnalysisPanel evidenceFileId={file.id} />}
        </li>
      ))}
    </ul>
  );
}
