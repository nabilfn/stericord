import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { createPack, listInstrumentSets } from "@/features/packs/api";
import { useAuth } from "@/contexts/AuthContext";

export function PackFormDialog({
  open,
  onClose,
  cycleId,
}: {
  open: boolean;
  onClose: () => void;
  cycleId: string;
}) {
  const { profile } = useAuth();
  const queryClient = useQueryClient();
  const { data: instrumentSets } = useQuery({ queryKey: ["instrument-sets"], queryFn: listInstrumentSets });

  const [instrumentSetId, setInstrumentSetId] = useState("");
  const [packCode, setPackCode] = useState("");
  const [expiryDate, setExpiryDate] = useState("");
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: createPack,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["packs", cycleId] });
      reset();
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to register pack"),
  });

  function reset() {
    setInstrumentSetId("");
    setPackCode("");
    setExpiryDate("");
    setError(null);
    onClose();
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!profile) return;
    setError(null);
    mutation.mutate({
      organization_id: profile.organization_id,
      instrument_set_id: instrumentSetId,
      sterilization_cycle_id: cycleId,
      pack_code: packCode,
      expiry_date: expiryDate || undefined,
    });
  }

  return (
    <Modal open={open} title="Register Pack" onClose={reset}>
      <form className="space-y-4" onSubmit={handleSubmit}>
        <div>
          <Label htmlFor="instrument_set_id">Instrument set</Label>
          <Select
            id="instrument_set_id"
            required
            value={instrumentSetId}
            onChange={(e) => setInstrumentSetId(e.target.value)}
          >
            <option value="" disabled>
              Select instrument set…
            </option>
            {instrumentSets?.map((set) => (
              <option key={set.id} value={set.id}>
                {set.name}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label htmlFor="pack_code">Pack code</Label>
          <Input
            id="pack_code"
            required
            value={packCode}
            onChange={(e) => setPackCode(e.target.value)}
            placeholder="PACK-2026-0891"
          />
        </div>
        <div>
          <Label htmlFor="expiry_date">Expiry date (optional)</Label>
          <Input id="expiry_date" type="date" value={expiryDate} onChange={(e) => setExpiryDate(e.target.value)} />
        </div>
        {error && <p className="text-sm text-fail">{error}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="secondary" onClick={reset}>
            Cancel
          </Button>
          <Button type="submit" disabled={mutation.isPending}>
            {mutation.isPending ? "Registering…" : "Register"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
