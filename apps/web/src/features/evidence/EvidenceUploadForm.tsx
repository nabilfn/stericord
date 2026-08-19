import { useRef, useState, type ChangeEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Upload, ScanEye } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Select } from "@/components/ui/Select";
import { useAuth } from "@/contexts/AuthContext";
import { uploadEvidence } from "@/features/evidence/api";
import { analyzeImageQuality, type ImageQualityResult } from "@/services/imageQuality";
import type { EvidenceType } from "@/types/database";

const evidenceTypes: EvidenceType[] = [
  "AUTOCLAVE_RECEIPT",
  "BOWIE_DICK",
  "BI_TRAY",
  "CHEMICAL_INDICATOR",
  "OT_INDICATOR",
  "WASHER_TEST",
  "GENERAL",
];

const REASON_LABEL: Record<string, string> = {
  IMAGE_TOO_BLURRY: "Image is too blurry — hold steady and refocus.",
  IMAGE_TOO_DARK: "Image is too dark — retake with better lighting.",
  GLARE_DETECTED: "Glare detected — tilt to avoid reflections.",
  INDICATOR_NOT_IN_FRAME: "Indicator not fully in frame.",
};

export function EvidenceUploadForm({ entityType, entityId }: { entityType: string; entityId: string }) {
  const { profile } = useAuth();
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [evidenceType, setEvidenceType] = useState<EvidenceType>("AUTOCLAVE_RECEIPT");
  const [error, setError] = useState<string | null>(null);
  const [checking, setChecking] = useState(false);
  const [retake, setRetake] = useState<ImageQualityResult | null>(null);

  const mutation = useMutation({
    mutationFn: uploadEvidence,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["evidence", entityType, entityId] });
      if (fileInputRef.current) fileInputRef.current.value = "";
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Upload failed"),
  });

  async function handleFileChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !profile) return;
    setError(null);
    setRetake(null);

    let quality: ImageQualityResult | undefined;
    if (file.type.startsWith("image/")) {
      setChecking(true);
      try {
        quality = await analyzeImageQuality(file, evidenceType);
      } catch {
        // If analysis itself fails (e.g. unsupported codec), don't block the
        // capture on a client-side quality bug -- just upload without a score.
        quality = undefined;
      } finally {
        setChecking(false);
      }
    }

    if (quality && quality.status === "RETAKE_REQUIRED") {
      setRetake(quality);
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }

    mutation.mutate({
      organizationId: profile.organization_id,
      entityType,
      entityId,
      evidenceType,
      file,
      capturedBy: profile.id,
      quality,
    });
  }

  return (
    <div className="space-y-2">
      <p className="flex items-center gap-1.5 text-xs text-slate-500">
        <ScanEye size={13} />
        Fill the frame with the indicator, avoid glare, and hold steady before capturing.
      </p>
      <div className="flex flex-wrap items-center gap-2">
        <Select
          className="max-w-[220px]"
          value={evidenceType}
          onChange={(e) => setEvidenceType(e.target.value as EvidenceType)}
        >
          {evidenceTypes.map((type) => (
            <option key={type} value={type}>
              {type.replace(/_/g, " ")}
            </option>
          ))}
        </Select>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/png,image/jpeg,application/pdf"
          className="hidden"
          onChange={(e) => void handleFileChange(e)}
        />
        <Button
          type="button"
          variant="secondary"
          disabled={mutation.isPending || checking}
          onClick={() => fileInputRef.current?.click()}
        >
          <Upload size={16} />
          {checking ? "Checking quality…" : mutation.isPending ? "Uploading…" : "Upload evidence"}
        </Button>
      </div>
      {retake && (
        <div className="rounded-md bg-amber-50 p-3 text-sm text-warning">
          <p className="font-semibold">Retake required</p>
          <ul className="mt-1 list-inside list-disc">
            {retake.reasons.map((r) => (
              <li key={r}>{REASON_LABEL[r] ?? r}</li>
            ))}
          </ul>
        </div>
      )}
      {error && <p className="text-sm text-fail">{error}</p>}
    </div>
  );
}
