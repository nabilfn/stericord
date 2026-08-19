import { useState, type FormEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";
import { Input, Label } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { createEquipment } from "@/features/equipment/api";
import { useAuth } from "@/contexts/AuthContext";
import type { EquipmentType } from "@/types/database";

const equipmentTypes: EquipmentType[] = [
  "STEAM_AUTOCLAVE",
  "ETO_STERILIZER",
  "PLASMA_STERILIZER",
  "WASHER_DISINFECTOR",
  "ULTRASONIC_CLEANER",
  "OTHER",
];

export function EquipmentFormDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { profile } = useAuth();
  const queryClient = useQueryClient();
  const [equipmentCode, setEquipmentCode] = useState("");
  const [equipmentType, setEquipmentType] = useState<EquipmentType>("STEAM_AUTOCLAVE");
  const [manufacturer, setManufacturer] = useState("");
  const [modelName, setModelName] = useState("");
  const [serialNumber, setSerialNumber] = useState("");
  const [location, setLocation] = useState("");
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: createEquipment,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["equipment"] });
      resetAndClose();
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to create equipment"),
  });

  function resetAndClose() {
    setEquipmentCode("");
    setManufacturer("");
    setModelName("");
    setSerialNumber("");
    setLocation("");
    setError(null);
    onClose();
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!profile) return;
    setError(null);
    mutation.mutate({
      organization_id: profile.organization_id,
      department_id: profile.department_id,
      equipment_code: equipmentCode,
      equipment_type: equipmentType,
      manufacturer: manufacturer || undefined,
      model_name: modelName || undefined,
      serial_number: serialNumber || undefined,
      location: location || undefined,
    });
  }

  return (
    <Modal open={open} title="Register Equipment" onClose={resetAndClose}>
      <form className="space-y-4" onSubmit={handleSubmit}>
        <div>
          <Label htmlFor="equipment_code">Equipment code</Label>
          <Input
            id="equipment_code"
            required
            value={equipmentCode}
            onChange={(e) => setEquipmentCode(e.target.value)}
            placeholder="AUTOCLAVE-A1"
          />
        </div>
        <div>
          <Label htmlFor="equipment_type">Equipment type</Label>
          <Select
            id="equipment_type"
            value={equipmentType}
            onChange={(e) => setEquipmentType(e.target.value as EquipmentType)}
          >
            {equipmentTypes.map((type) => (
              <option key={type} value={type}>
                {type.replace(/_/g, " ")}
              </option>
            ))}
          </Select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label htmlFor="manufacturer">Manufacturer</Label>
            <Input id="manufacturer" value={manufacturer} onChange={(e) => setManufacturer(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="model_name">Model</Label>
            <Input id="model_name" value={modelName} onChange={(e) => setModelName(e.target.value)} />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label htmlFor="serial_number">Serial number</Label>
            <Input id="serial_number" value={serialNumber} onChange={(e) => setSerialNumber(e.target.value)} />
          </div>
          <div>
            <Label htmlFor="location">Location</Label>
            <Input id="location" value={location} onChange={(e) => setLocation(e.target.value)} />
          </div>
        </div>
        {error && <p className="text-sm text-fail">{error}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="secondary" onClick={resetAndClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={mutation.isPending}>
            {mutation.isPending ? "Saving…" : "Register"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
