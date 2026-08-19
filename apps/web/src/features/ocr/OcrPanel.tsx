import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ScanText, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { Badge } from "@/components/ui/Badge";
import { confirmOcrExtraction, listOcrExtractions, requestOcrExtraction } from "@/features/ocr/api";
import type { ExtractedCycleFields } from "@/types/database";

const EMPTY_FIELDS: Partial<ExtractedCycleFields> = {
  cycle_number: "",
  temperature: null,
  pressure: null,
  hold_time_seconds: null,
  date: "",
  time: "",
  machine_identifier: "",
  result: "",
};

export function OcrPanel({ evidenceFileId }: { evidenceFileId: string }) {
  const queryClient = useQueryClient();
  const [showRawText, setShowRawText] = useState(false);
  const [fields, setFields] = useState<Partial<ExtractedCycleFields>>(EMPTY_FIELDS);

  const extractionsQuery = useQuery({
    queryKey: ["ocr-extractions", evidenceFileId],
    queryFn: () => listOcrExtractions(evidenceFileId),
  });
  const latest = extractionsQuery.data?.[0];

  useEffect(() => {
    if (!latest) return;
    setFields({ ...EMPTY_FIELDS, ...(latest.human_confirmed_fields ?? latest.extracted_fields ?? {}) });
    // Deliberately keyed on the record's identity, not the `latest` object
    // reference: a background refetch returns a new object for the same
    // row, which must not clobber in-progress edits the user hasn't saved.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [latest?.id]);

  const extractMutation = useMutation({
    mutationFn: () => requestOcrExtraction(evidenceFileId),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["ocr-extractions", evidenceFileId] }),
  });

  const confirmMutation = useMutation({
    mutationFn: () => confirmOcrExtraction(latest!.id, fields),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["ocr-extractions", evidenceFileId] }),
  });

  function updateField<K extends keyof ExtractedCycleFields>(key: K, value: string) {
    setFields((prev) => ({
      ...prev,
      [key]: key === "temperature" || key === "pressure" || key === "hold_time_seconds" ? (value === "" ? null : Number(value)) : value,
    }));
  }

  if (extractionsQuery.isLoading) return <p className="text-xs text-slate-400">Loading OCR status…</p>;

  if (!latest) {
    return (
      <Button
        variant="secondary"
        className="px-2 py-1 text-xs"
        disabled={extractMutation.isPending}
        onClick={() => extractMutation.mutate()}
      >
        <ScanText size={13} />
        {extractMutation.isPending ? "Extracting…" : "Extract with OCR"}
      </Button>
    );
  }

  return (
    <div className="mt-2 space-y-3 rounded-md border border-slate-200 bg-slate-50 p-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Badge tone={latest.status === "COMPLETED" ? "info" : latest.status === "FAILED" ? "fail" : "neutral"}>
            {latest.status.replace(/_/g, " ")}
          </Badge>
          {latest.confirmed_at && (
            <span className="flex items-center gap-1 text-xs text-pass">
              <CheckCircle2 size={13} /> Confirmed
            </span>
          )}
        </div>
        <Button
          variant="ghost"
          className="px-2 py-1 text-xs"
          disabled={extractMutation.isPending}
          onClick={() => extractMutation.mutate()}
        >
          Re-run OCR
        </Button>
      </div>

      {latest.status === "NOT_CONFIGURED" && (
        <p className="text-xs text-slate-500">
          Document AI isn't configured in this environment. Enter values manually below and confirm.
        </p>
      )}
      {latest.status === "FAILED" && (
        <p className="text-xs text-fail">{latest.error_message ?? "OCR failed."}</p>
      )}
      {latest.status === "COMPLETED" && latest.raw_text && (
        <div>
          <button
            type="button"
            className="text-xs text-sc-blue underline"
            onClick={() => setShowRawText((s) => !s)}
          >
            {showRawText ? "Hide" : "Show"} raw OCR text
          </button>
          {showRawText && (
            <pre className="mt-1 max-h-32 overflow-y-auto whitespace-pre-wrap rounded bg-white p-2 text-xs text-slate-600">
              {latest.raw_text}
            </pre>
          )}
        </div>
      )}

      <div className="grid grid-cols-2 gap-2">
        <FieldInput label="Cycle number" value={fields.cycle_number} onChange={(v) => updateField("cycle_number", v)} />
        <FieldInput label="Machine ID" value={fields.machine_identifier} onChange={(v) => updateField("machine_identifier", v)} />
        <FieldInput label="Temperature (°C)" value={fields.temperature} onChange={(v) => updateField("temperature", v)} type="number" />
        <FieldInput label="Pressure (bar)" value={fields.pressure} onChange={(v) => updateField("pressure", v)} type="number" />
        <FieldInput label="Hold time (sec)" value={fields.hold_time_seconds} onChange={(v) => updateField("hold_time_seconds", v)} type="number" />
        <FieldInput label="Result" value={fields.result} onChange={(v) => updateField("result", v)} />
        <FieldInput label="Date" value={fields.date} onChange={(v) => updateField("date", v)} />
        <FieldInput label="Time" value={fields.time} onChange={(v) => updateField("time", v)} />
      </div>

      <Button className="px-3 py-1.5 text-xs" disabled={confirmMutation.isPending} onClick={() => confirmMutation.mutate()}>
        {confirmMutation.isPending ? "Saving…" : latest.confirmed_at ? "Update confirmation" : "Confirm values"}
      </Button>
    </div>
  );
}

function FieldInput({
  label,
  value,
  onChange,
  type = "text",
}: {
  label: string;
  value: string | number | null | undefined;
  onChange: (value: string) => void;
  type?: string;
}) {
  return (
    <div>
      <Label className="text-[11px]">{label}</Label>
      <Input
        className="py-1 text-xs"
        type={type}
        value={value ?? ""}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}
