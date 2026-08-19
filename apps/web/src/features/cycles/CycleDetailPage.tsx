import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Plus } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { getCycle, listVerifications, startCycle, submitCycleForVerification } from "@/features/cycles/api";
import { CycleStatusBadge } from "@/features/cycles/CycleStatusBadge";
import { CompleteCycleDialog } from "@/features/cycles/CompleteCycleDialog";
import { VerifyCycleDialog } from "@/features/cycles/VerifyCycleDialog";
import { PackListForCycle } from "@/features/packs/PackListForCycle";
import { PackFormDialog } from "@/features/packs/PackFormDialog";
import { EvidenceUploadForm } from "@/features/evidence/EvidenceUploadForm";
import { EvidenceList } from "@/features/evidence/EvidenceList";
import { getEquipment } from "@/features/equipment/api";
import { useAuth } from "@/contexts/AuthContext";

export function CycleDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { hasRole } = useAuth();
  const queryClient = useQueryClient();

  const [packFormOpen, setPackFormOpen] = useState(false);
  const [completeFormOpen, setCompleteFormOpen] = useState(false);
  const [verifyFormOpen, setVerifyFormOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const cycleQuery = useQuery({
    queryKey: ["cycles", id],
    queryFn: () => getCycle(id!),
    enabled: Boolean(id),
  });

  const equipmentQuery = useQuery({
    queryKey: ["equipment", cycleQuery.data?.equipment_id],
    queryFn: () => getEquipment(cycleQuery.data!.equipment_id),
    enabled: Boolean(cycleQuery.data?.equipment_id),
  });

  const verificationsQuery = useQuery({
    queryKey: ["verifications", "sterilization_cycle", id],
    queryFn: () => listVerifications("sterilization_cycle", id!),
    enabled: Boolean(id),
  });

  const startMutation = useMutation({
    mutationFn: () => startCycle(id!),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["cycles", id] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to start cycle"),
  });

  const submitMutation = useMutation({
    mutationFn: () => submitCycleForVerification(id!),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["cycles", id] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to submit for verification"),
  });

  const cycle = cycleQuery.data;
  const canOperate = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR", "CSSD_TECHNICIAN");
  const canVerify = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR");

  if (cycleQuery.isLoading) return <p className="text-sm text-slate-500">Loading…</p>;
  if (!cycle) return null;

  return (
    <div className="space-y-6">
      <Link to="/cycles" className="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700">
        <ArrowLeft size={14} />
        Back to cycles
      </Link>

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-slate-900">{cycle.cycle_number}</h1>
          <p className="text-sm text-slate-500">
            {cycle.cycle_type} · {equipmentQuery.data?.equipment_code ?? "…"}
          </p>
        </div>
        <CycleStatusBadge status={cycle.cycle_status} />
      </div>

      {error && <p className="text-sm text-fail">{error}</p>}

      {canOperate && (
        <div className="flex flex-wrap gap-2">
          {cycle.cycle_status === "CREATED" && (
            <Button disabled={startMutation.isPending} onClick={() => startMutation.mutate()}>
              Start Cycle
            </Button>
          )}
          {cycle.cycle_status === "RUNNING" && <Button onClick={() => setCompleteFormOpen(true)}>Complete Cycle</Button>}
          {cycle.cycle_status === "COMPLETED" && (
            <Button disabled={submitMutation.isPending} onClick={() => submitMutation.mutate()}>
              Submit for Verification
            </Button>
          )}
          {cycle.cycle_status === "PENDING_VERIFICATION" && canVerify && (
            <Button onClick={() => setVerifyFormOpen(true)}>Verify Cycle</Button>
          )}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Cycle Parameters</CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-3 gap-4 text-sm">
          <Field label="Temperature" value={cycle.temperature ? `${cycle.temperature} °C` : null} />
          <Field label="Pressure" value={cycle.pressure ? `${cycle.pressure} bar` : null} />
          <Field label="Hold time" value={cycle.hold_time_seconds ? `${cycle.hold_time_seconds}s` : null} />
          <Field label="Started" value={cycle.started_at ? new Date(cycle.started_at).toLocaleString() : null} />
          <Field label="Completed" value={cycle.completed_at ? new Date(cycle.completed_at).toLocaleString() : null} />
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Instrument Packs</CardTitle>
          {canOperate && ["CREATED", "RUNNING"].includes(cycle.cycle_status) && (
            <Button variant="secondary" className="px-2 py-1 text-xs" onClick={() => setPackFormOpen(true)}>
              <Plus size={14} />
              Register Pack
            </Button>
          )}
        </CardHeader>
        <CardContent>
          <PackListForCycle cycleId={cycle.id} cycleStatus={cycle.cycle_status} />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Evidence</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {canOperate && <EvidenceUploadForm entityType="sterilization_cycle" entityId={cycle.id} />}
          <EvidenceList entityType="sterilization_cycle" entityId={cycle.id} />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Verification History</CardTitle>
        </CardHeader>
        <CardContent>
          {verificationsQuery.data && verificationsQuery.data.length > 0 ? (
            <ul className="space-y-2 text-sm">
              {verificationsQuery.data.map((v) => (
                <li key={v.id} className="flex items-center justify-between border-b border-slate-100 pb-2 last:border-0">
                  <span>
                    <strong>{v.human_result}</strong>
                    {v.notes ? ` — ${v.notes}` : ""}
                  </span>
                  <span className="text-slate-400">{new Date(v.verified_at).toLocaleString()}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-slate-500">No verification recorded yet.</p>
          )}
        </CardContent>
      </Card>

      <PackFormDialog open={packFormOpen} onClose={() => setPackFormOpen(false)} cycleId={cycle.id} />
      <CompleteCycleDialog open={completeFormOpen} onClose={() => setCompleteFormOpen(false)} cycleId={cycle.id} />
      <VerifyCycleDialog open={verifyFormOpen} onClose={() => setVerifyFormOpen(false)} cycleId={cycle.id} />
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
