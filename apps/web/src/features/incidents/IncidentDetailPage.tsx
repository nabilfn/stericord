import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Badge";
import { useAuth } from "@/contexts/AuthContext";
import { acknowledgeIncident, getIncident, resolveIncident } from "@/features/incidents/api";
import { IncidentStatusBadge } from "@/features/incidents/IncidentStatusBadge";
import { listQuarantinesByIncident, releaseQuarantine } from "@/features/quarantine/api";

const priorityTone: Record<string, "neutral" | "warning" | "fail" | "info"> = {
  LOW: "neutral",
  MEDIUM: "info",
  HIGH: "warning",
  CRITICAL: "fail",
};

export function IncidentDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { hasRole } = useAuth();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);

  const incidentQuery = useQuery({
    queryKey: ["incidents", id],
    queryFn: () => getIncident(id!),
    enabled: Boolean(id),
  });

  const quarantinesQuery = useQuery({
    queryKey: ["quarantines", "by-incident", id],
    queryFn: () => listQuarantinesByIncident(id!),
    enabled: Boolean(id),
  });

  const acknowledgeMutation = useMutation({
    mutationFn: () => acknowledgeIncident(id!),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["incidents", id] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to acknowledge"),
  });

  const resolveMutation = useMutation({
    mutationFn: ({ notes, close }: { notes: string; close: boolean }) => resolveIncident(id!, notes, close),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["incidents", id] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to resolve"),
  });

  const releaseQuarantineMutation = useMutation({
    mutationFn: ({ quarantineId, reason }: { quarantineId: string; reason: string }) =>
      releaseQuarantine(quarantineId, reason),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["quarantines", "by-incident", id] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to release quarantine"),
  });

  const incident = incidentQuery.data;
  const canManage = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR");

  if (incidentQuery.isLoading) return <p className="text-sm text-slate-500">Loading…</p>;
  if (!incident) return null;

  return (
    <div className="space-y-6">
      <Link to="/incidents" className="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700">
        <ArrowLeft size={14} />
        Back to incidents
      </Link>

      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-slate-900">{incident.source_type.replace(/_/g, " ")}</h1>
          <p className="text-sm text-slate-500">Detected {new Date(incident.detected_at).toLocaleString()}</p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone={priorityTone[incident.priority] ?? "neutral"}>{incident.priority}</Badge>
          <IncidentStatusBadge status={incident.status} />
        </div>
      </div>

      {error && <p className="text-sm text-fail">{error}</p>}

      {canManage && !["RESOLVED", "CLOSED"].includes(incident.status) && (
        <div className="flex flex-wrap gap-2">
          {["DETECTED", "ALERTED"].includes(incident.status) && (
            <Button disabled={acknowledgeMutation.isPending} onClick={() => acknowledgeMutation.mutate()}>
              Acknowledge
            </Button>
          )}
          <Button
            variant="secondary"
            onClick={() => {
              const notes = window.prompt("Resolution notes:");
              if (notes) resolveMutation.mutate({ notes, close: false });
            }}
          >
            Resolve
          </Button>
          <Button
            variant="danger"
            onClick={() => {
              const notes = window.prompt("Closing notes:");
              if (notes) resolveMutation.mutate({ notes, close: true });
            }}
          >
            Close
          </Button>
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Details</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          <p>{incident.description}</p>
          {incident.resolution_notes && (
            <p className="border-t border-slate-100 pt-2 text-slate-600">
              <strong>Resolution:</strong> {incident.resolution_notes}
            </p>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Related Quarantine</CardTitle>
        </CardHeader>
        <CardContent>
          {quarantinesQuery.data && quarantinesQuery.data.length > 0 ? (
            <ul className="space-y-3">
              {quarantinesQuery.data.map((q) => (
                <li key={q.id} className="flex items-center justify-between text-sm">
                  <span>
                    {q.scope_type} — {q.reason}
                    <Badge className="ml-2" tone={q.status === "ACTIVE" ? "fail" : "neutral"}>
                      {q.status}
                    </Badge>
                  </span>
                  {canManage && q.status === "ACTIVE" && (
                    <Button
                      variant="secondary"
                      className="px-2 py-1 text-xs"
                      disabled={releaseQuarantineMutation.isPending}
                      onClick={() => {
                        const reason = window.prompt("Release reason:");
                        if (reason) releaseQuarantineMutation.mutate({ quarantineId: q.id, reason });
                      }}
                    >
                      Release
                    </Button>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-slate-500">No quarantine linked to this incident.</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
