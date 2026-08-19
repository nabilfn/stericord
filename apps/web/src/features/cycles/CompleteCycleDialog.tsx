import { useState, type FormEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { completeCycle } from "@/features/cycles/api";

export function CompleteCycleDialog({
  open,
  onClose,
  cycleId,
}: {
  open: boolean;
  onClose: () => void;
  cycleId: string;
}) {
  const queryClient = useQueryClient();
  const [temperature, setTemperature] = useState("");
  const [pressure, setPressure] = useState("");
  const [holdTimeSeconds, setHoldTimeSeconds] = useState("");
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: () =>
      completeCycle(cycleId, {
        temperature: temperature ? Number(temperature) : undefined,
        pressure: pressure ? Number(pressure) : undefined,
        holdTimeSeconds: holdTimeSeconds ? Number(holdTimeSeconds) : undefined,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["cycles", cycleId] });
      void queryClient.invalidateQueries({ queryKey: ["packs", cycleId] });
      reset();
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to complete cycle"),
  });

  function reset() {
    setTemperature("");
    setPressure("");
    setHoldTimeSeconds("");
    setError(null);
    onClose();
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    mutation.mutate();
  }

  return (
    <Modal open={open} title="Complete Cycle" onClose={reset}>
      <form className="space-y-4" onSubmit={handleSubmit}>
        <p className="text-sm text-slate-500">Enter the final readings from the autoclave receipt.</p>
        <div className="grid grid-cols-3 gap-3">
          <div>
            <Label htmlFor="temperature">Temp (°C)</Label>
            <Input id="temperature" type="number" step="0.1" value={temperature} onChange={(e) => setTemperature(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="pressure">Pressure (bar)</Label>
            <Input id="pressure" type="number" step="0.01" value={pressure} onChange={(e) => setPressure(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="hold_time_seconds">Hold (sec)</Label>
            <Input
              id="hold_time_seconds"
              type="number"
              value={holdTimeSeconds}
              onChange={(e) => setHoldTimeSeconds(e.target.value)}
            />
          </div>
        </div>
        {error && <p className="text-sm text-fail">{error}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="secondary" onClick={reset}>
            Cancel
          </Button>
          <Button type="submit" disabled={mutation.isPending}>
            {mutation.isPending ? "Saving…" : "Complete Cycle"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
