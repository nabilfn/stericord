import { useRef, useState, type ChangeEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Upload } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Select } from "@/components/ui/Select";
import { useAuth } from "@/contexts/AuthContext";
import { uploadEvidence } from "@/features/evidence/api";
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

export function EvidenceUploadForm({ entityType, entityId }: { entityType: string; entityId: string }) {
  const { profile } = useAuth();
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [evidenceType, setEvidenceType] = useState<EvidenceType>("AUTOCLAVE_RECEIPT");
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: uploadEvidence,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["evidence", entityType, entityId] });
      if (fileInputRef.current) fileInputRef.current.value = "";
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Upload failed"),
  });

  function handleFileChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !profile) return;
    setError(null);
    mutation.mutate({
      organizationId: profile.organization_id,
      entityType,
      entityId,
      evidenceType,
      file,
      capturedBy: profile.id,
    });
  }

  return (
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
        onChange={handleFileChange}
      />
      <Button
        type="button"
        variant="secondary"
        disabled={mutation.isPending}
        onClick={() => fileInputRef.current?.click()}
      >
        <Upload size={16} />
        {mutation.isPending ? "Uploading…" : "Upload evidence"}
      </Button>
      {error && <p className="w-full text-sm text-fail">{error}</p>}
    </div>
  );
}
