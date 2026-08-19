import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { listEquipment } from "@/features/equipment/api";
import { EquipmentStatusBadge } from "@/features/equipment/EquipmentStatusBadge";
import { EquipmentFormDialog } from "@/features/equipment/EquipmentFormDialog";

export function EquipmentListPage() {
  const [formOpen, setFormOpen] = useState(false);
  const { data: equipment, isLoading, isError, error } = useQuery({
    queryKey: ["equipment"],
    queryFn: listEquipment,
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-slate-900">Equipment</h1>
          <p className="text-sm text-slate-500">Sterilization and decontamination equipment registry.</p>
        </div>
        <Button onClick={() => setFormOpen(true)}>
          <Plus size={16} />
          Register Equipment
        </Button>
      </div>

      <Card className="overflow-hidden">
        {isLoading && <p className="p-5 text-sm text-slate-500">Loading equipment…</p>}
        {isError && (
          <p className="p-5 text-sm text-fail">
            {error instanceof Error ? error.message : "Failed to load equipment"}
          </p>
        )}
        {equipment && equipment.length === 0 && (
          <p className="p-5 text-sm text-slate-500">No equipment registered yet.</p>
        )}
        {equipment && equipment.length > 0 && (
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Code
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Type
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Location
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Status
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {equipment.map((item) => (
                <tr key={item.id} className="hover:bg-slate-50">
                  <td className="px-5 py-3 text-sm font-medium text-navy">
                    <Link to={`/equipment/${item.id}`}>{item.equipment_code}</Link>
                  </td>
                  <td className="px-5 py-3 text-sm text-slate-700">{item.equipment_type.replace(/_/g, " ")}</td>
                  <td className="px-5 py-3 text-sm text-slate-700">{item.location ?? "—"}</td>
                  <td className="px-5 py-3 text-sm">
                    <EquipmentStatusBadge status={item.operating_status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <EquipmentFormDialog open={formOpen} onClose={() => setFormOpen(false)} />
    </div>
  );
}
