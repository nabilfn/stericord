import { useState, type FormEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { createCycle } from "@/features/cycles/api";
import { listEquipment } from "@/features/equipment/api";
import { useAuth } from "@/contexts/AuthContext";

export function CycleFormDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { profile } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { data: equipment } = useQuery({ queryKey: ["equipment"], queryFn: listEquipment });

  const [equipmentId, setEquipmentId] = useState("");
  const [cycleNumber, setCycleNumber] = useState("");
  const [cycleType, setCycleType] = useState("");
  const [error, setError] = useState<string | null>(null);

  const activeEquipment = equipment?.filter((e) => e.operating_status === "ACTIVE") ?? [];

  const mutation = useMutation({
    mutationFn: createCycle,
    onSuccess: (cycle) => {
      void queryClient.invalidateQueries({ queryKey: ["cycles"] });
      reset();
      navigate(`/cycles/${cycle.id}`);
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to create cycle"),
  });

  function reset() {
    setEquipmentId("");
    setCycleNumber("");
    setCycleType("");
    setError(null);
    onClose();
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!profile) return;
    setError(null);
    mutation.mutate({
      organization_id: profile.organization_id,
      equipment_id: equipmentId,
      cycle_number: cycleNumber,
      cycle_type: cycleType,
      operator_user_id: profile.id,
    });
  }

  return (
    <Modal open={open} title="Create Sterilization Cycle" onClose={reset}>
      <form className="space-y-4" onSubmit={handleSubmit}>
        <div>
          <Label htmlFor="equipment_id">Equipment</Label>
          <Select id="equipment_id" required value={equipmentId} onChange={(e) => setEquipmentId(e.target.value)}>
            <option value="" disabled>
              Select equipment…
            </option>
            {activeEquipment.map((item) => (
              <option key={item.id} value={item.id}>
                {item.equipment_code} ({item.equipment_type.replace(/_/g, " ")})
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label htmlFor="cycle_number">Cycle number</Label>
          <Input
            id="cycle_number"
            required
            value={cycleNumber}
            onChange={(e) => setCycleNumber(e.target.value)}
            placeholder="CYC-2026-0142"
          />
        </div>
        <div>
          <Label htmlFor="cycle_type">Cycle type</Label>
          <Input
            id="cycle_type"
            required
            value={cycleType}
            onChange={(e) => setCycleType(e.target.value)}
            placeholder="Prevac 134°C 4min"
          />
        </div>
        {error && <p className="text-sm text-fail">{error}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="secondary" onClick={reset}>
            Cancel
          </Button>
          <Button type="submit" disabled={mutation.isPending}>
            {mutation.isPending ? "Creating…" : "Create Cycle"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
