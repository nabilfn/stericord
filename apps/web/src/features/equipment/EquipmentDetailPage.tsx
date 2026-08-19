import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import { getEquipment, getEquipmentStatusHistory, updateEquipmentStatus } from "@/features/equipment/api";
import { EquipmentStatusBadge } from "@/features/equipment/EquipmentStatusBadge";
import { useAuth } from "@/contexts/AuthContext";
import type { EquipmentStatus } from "@/types/database";

const statuses: EquipmentStatus[] = ["ACTIVE", "LOCKED_OUT", "MAINTENANCE", "DECOMMISSIONED"];

export function EquipmentDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { hasRole } = useAuth();
  const queryClient = useQueryClient();
  const [pendingStatus, setPendingStatus] = useState<EquipmentStatus | "">("");

  const equipmentQuery = useQuery({
    queryKey: ["equipment", id],
    queryFn: () => getEquipment(id!),
    enabled: Boolean(id),
  });

  const historyQuery = useQuery({
    queryKey: ["equipment", id, "status-history"],
    queryFn: () => getEquipmentStatusHistory(id!),
    enabled: Boolean(id),
  });

  const statusMutation = useMutation({
    mutationFn: (status: EquipmentStatus) => updateEquipmentStatus(id!, status),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["equipment", id] });
      void queryClient.invalidateQueries({ queryKey: ["equipment", id, "status-history"] });
      setPendingStatus("");
    },
  });

  const canManage = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR", "BIOMEDICAL_ENGINEER");
  const equipment = equipmentQuery.data;

  return (
    <div className="space-y-6">
      <Link to="/equipment" className="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700">
        <ArrowLeft size={14} />
        Back to equipment
      </Link>

      {equipmentQuery.isLoading && <p className="text-sm text-slate-500">Loading…</p>}

      {equipment && (
        <>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-xl font-semibold text-slate-900">{equipment.equipment_code}</h1>
              <p className="text-sm text-slate-500">{equipment.equipment_type.replace(/_/g, " ")}</p>
            </div>
            <EquipmentStatusBadge status={equipment.operating_status} />
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Details</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-2 gap-4 text-sm">
              <Field label="Manufacturer" value={equipment.manufacturer} />
              <Field label="Model" value={equipment.model_name} />
              <Field label="Serial number" value={equipment.serial_number} />
              <Field label="Location" value={equipment.location} />
            </CardContent>
          </Card>

          {canManage && (
            <Card>
              <CardHeader>
                <CardTitle>Change status</CardTitle>
              </CardHeader>
              <CardContent className="flex items-center gap-3">
                <Select
                  className="max-w-xs"
                  value={pendingStatus}
                  onChange={(e) => setPendingStatus(e.target.value as EquipmentStatus)}
                >
                  <option value="" disabled>
                    Select new status…
                  </option>
                  {statuses.map((status) => (
                    <option key={status} value={status}>
                      {status.replace("_", " ")}
                    </option>
                  ))}
                </Select>
                <Button
                  disabled={!pendingStatus || statusMutation.isPending}
                  onClick={() => pendingStatus && statusMutation.mutate(pendingStatus)}
                >
                  Apply
                </Button>
              </CardContent>
            </Card>
          )}

          <Card>
            <CardHeader>
              <CardTitle>Status history</CardTitle>
            </CardHeader>
            <CardContent>
              {historyQuery.data && historyQuery.data.length > 0 ? (
                <ul className="space-y-2 text-sm">
                  {historyQuery.data.map((event) => (
                    <li key={event.id} className="flex items-center justify-between border-b border-slate-100 pb-2 last:border-0">
                      <span>
                        {event.previous_status ? `${event.previous_status} → ` : "Created as "}
                        <strong>{event.new_status}</strong>
                      </span>
                      <span className="text-slate-400">{new Date(event.changed_at).toLocaleString()}</span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-sm text-slate-500">No status changes recorded.</p>
              )}
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

function Field({ label, value }: { label: string; value: string | null }) {
  return (
    <div>
      <p className="text-xs font-medium uppercase tracking-wide text-slate-400">{label}</p>
      <p className="text-slate-800">{value ?? "—"}</p>
    </div>
  );
}
