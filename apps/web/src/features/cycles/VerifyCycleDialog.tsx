import { useState, type FormEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";
import { Label } from "@/components/ui/Input";
import { verifyCycle } from "@/features/cycles/api";
import type { VerificationResult } from "@/types/database";

const results: { value: VerificationResult; label: string; description: string }[] = [
  { value: "PASS", label: "PASS", description: "All indicators and parameters are within spec. Packs may be released individually." },
  { value: "FAIL", label: "FAIL", description: "Sterility cannot be confirmed. All packs in this cycle will be quarantined." },
  { value: "UNDETERMINED", label: "UNDETERMINED", description: "Inconclusive — stays pending verification for further review." },
];

export function VerifyCycleDialog({
  open,
  onClose,
  cycleId,
}: {
  open: boolean;
  onClose: () => void;
  cycleId: string;
}) {
  const queryClient = useQueryClient();
  const [result, setResult] = useState<VerificationResult | "">("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: () => verifyCycle(cycleId, result as VerificationResult, notes || undefined),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["cycles", cycleId] });
      void queryClient.invalidateQueries({ queryKey: ["packs", cycleId] });
      reset();
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to record verification"),
  });

  function reset() {
    setResult("");
    setNotes("");
    setError(null);
    onClose();
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!result) return;
    setError(null);
    mutation.mutate();
  }

  return (
    <Modal open={open} title="Manual Verification" onClose={reset}>
      <form className="space-y-4" onSubmit={handleSubmit}>
        <div className="space-y-2">
          {results.map((r) => (
            <label
              key={r.value}
              className="flex cursor-pointer items-start gap-3 rounded-md border border-slate-200 p-3 has-[:checked]:border-navy has-[:checked]:bg-sc-blue-light"
            >
              <input
                type="radio"
                name="verification_result"
                value={r.value}
                checked={result === r.value}
                onChange={() => setResult(r.value)}
                className="mt-1"
              />
              <span>
                <span className="block text-sm font-semibold">{r.label}</span>
                <span className="block text-xs text-slate-500">{r.description}</span>
              </span>
            </label>
          ))}
        </div>
        <div>
          <Label htmlFor="notes">Notes</Label>
          <textarea
            id="notes"
            rows={3}
            className="block w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-navy focus:outline-none focus:ring-1 focus:ring-navy"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Observations, indicator readings, reasoning…"
          />
        </div>
        {error && <p className="text-sm text-fail">{error}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="secondary" onClick={reset}>
            Cancel
          </Button>
          <Button type="submit" disabled={!result || mutation.isPending}>
            {mutation.isPending ? "Recording…" : "Record Verification"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
