import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Sparkles } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { listAiAnalyses, requestAiAnalysis } from "@/features/ai/api";

const RESULT_TONE: Record<string, "pass" | "fail" | "warning" | "neutral"> = {
  PASS: "pass",
  FAIL: "fail",
  UNDETERMINED: "warning",
};

const BAND_TONE: Record<string, "pass" | "warning" | "fail"> = {
  HIGH: "pass",
  MEDIUM: "warning",
  LOW: "fail",
};

export function AiAnalysisPanel({ evidenceFileId }: { evidenceFileId: string }) {
  const [expanded, setExpanded] = useState(false);
  const queryClient = useQueryClient();

  const analysesQuery = useQuery({
    queryKey: ["ai-analyses", evidenceFileId],
    queryFn: () => listAiAnalyses(evidenceFileId),
    enabled: expanded,
  });
  const latest = analysesQuery.data?.[0];

  const analyzeMutation = useMutation({
    mutationFn: () => requestAiAnalysis(evidenceFileId),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["ai-analyses", evidenceFileId] }),
  });

  if (!expanded) {
    return (
      <Button variant="secondary" className="mt-2 px-2 py-1 text-xs" onClick={() => setExpanded(true)}>
        <Sparkles size={13} />
        AI analysis
      </Button>
    );
  }

  return (
    <div className="mt-2 space-y-2 rounded-md border border-slate-200 bg-slate-50 p-3">
      {analysesQuery.isLoading && <p className="text-xs text-slate-400">Loading…</p>}

      {!analysesQuery.isLoading && !latest && (
        <Button
          variant="secondary"
          className="px-2 py-1 text-xs"
          disabled={analyzeMutation.isPending}
          onClick={() => analyzeMutation.mutate()}
        >
          {analyzeMutation.isPending ? "Analyzing…" : "Analyze with AI"}
        </Button>
      )}

      {latest && (
        <>
          <div className="flex flex-wrap items-center gap-2">
            <Badge tone={latest.status === "COMPLETED" ? "info" : latest.status === "FAILED" ? "fail" : "neutral"}>
              {latest.status.replace(/_/g, " ")}
            </Badge>
            {latest.suggested_result && (
              <Badge tone={RESULT_TONE[latest.suggested_result] ?? "neutral"}>
                Suggests {latest.suggested_result}
              </Badge>
            )}
            {latest.confidence_band && (
              <Badge tone={BAND_TONE[latest.confidence_band] ?? "neutral"}>
                {latest.confidence_band} confidence{latest.confidence != null ? ` (${Math.round(latest.confidence * 100)}%)` : ""}
              </Badge>
            )}
          </div>

          {latest.status === "NOT_CONFIGURED" && (
            <p className="text-xs text-slate-500">Gemini isn't configured in this environment.</p>
          )}
          {latest.status === "FAILED" && <p className="text-xs text-fail">{latest.error_message ?? "Analysis failed."}</p>}

          {latest.observations.length > 0 && (
            <ul className="list-inside list-disc text-xs text-slate-600">
              {latest.observations.map((o, i) => (
                <li key={i}>{o}</li>
              ))}
            </ul>
          )}

          <p className="text-[11px] text-slate-400">
            Advisory only — a human always confirms the result during verification.
          </p>

          <Button
            variant="ghost"
            className="px-2 py-1 text-xs"
            disabled={analyzeMutation.isPending}
            onClick={() => analyzeMutation.mutate()}
          >
            Re-run analysis
          </Button>
        </>
      )}
    </div>
  );
}
