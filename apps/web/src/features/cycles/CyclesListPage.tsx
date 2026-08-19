import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { listCycles } from "@/features/cycles/api";
import { CycleStatusBadge } from "@/features/cycles/CycleStatusBadge";
import { CycleFormDialog } from "@/features/cycles/CycleFormDialog";

export function CyclesListPage() {
  const [formOpen, setFormOpen] = useState(false);
  const { data: cycles, isLoading, isError, error } = useQuery({
    queryKey: ["cycles"],
    queryFn: listCycles,
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-slate-900">Sterilization Cycles</h1>
          <p className="text-sm text-slate-500">Create, run, and verify autoclave/washer cycles.</p>
        </div>
        <Button onClick={() => setFormOpen(true)}>
          <Plus size={16} />
          Create Cycle
        </Button>
      </div>

      <Card className="overflow-hidden">
        {isLoading && <p className="p-5 text-sm text-slate-500">Loading cycles…</p>}
        {isError && (
          <p className="p-5 text-sm text-fail">{error instanceof Error ? error.message : "Failed to load cycles"}</p>
        )}
        {cycles && cycles.length === 0 && <p className="p-5 text-sm text-slate-500">No cycles yet.</p>}
        {cycles && cycles.length > 0 && (
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Cycle
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Type
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Created
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Status
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {cycles.map((cycle) => (
                <tr key={cycle.id} className="hover:bg-slate-50">
                  <td className="px-5 py-3 text-sm font-medium text-navy">
                    <Link to={`/cycles/${cycle.id}`}>{cycle.cycle_number}</Link>
                  </td>
                  <td className="px-5 py-3 text-sm text-slate-700">{cycle.cycle_type}</td>
                  <td className="px-5 py-3 text-sm text-slate-700">
                    {new Date(cycle.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-5 py-3 text-sm">
                    <CycleStatusBadge status={cycle.cycle_status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <CycleFormDialog open={formOpen} onClose={() => setFormOpen(false)} />
    </div>
  );
}
