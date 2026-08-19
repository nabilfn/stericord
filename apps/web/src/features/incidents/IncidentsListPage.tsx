import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { listIncidents } from "@/features/incidents/api";
import { IncidentStatusBadge } from "@/features/incidents/IncidentStatusBadge";

const priorityTone: Record<string, "neutral" | "warning" | "fail" | "info"> = {
  LOW: "neutral",
  MEDIUM: "info",
  HIGH: "warning",
  CRITICAL: "fail",
};

export function IncidentsListPage() {
  const { data: incidents, isLoading, isError, error } = useQuery({
    queryKey: ["incidents"],
    queryFn: listIncidents,
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">Incidents</h1>
        <p className="text-sm text-slate-500">Safety events detected across CSSD and OT point-of-use.</p>
      </div>

      <Card className="overflow-hidden">
        {isLoading && <p className="p-5 text-sm text-slate-500">Loading incidents…</p>}
        {isError && (
          <p className="p-5 text-sm text-fail">{error instanceof Error ? error.message : "Failed to load incidents"}</p>
        )}
        {incidents && incidents.length === 0 && <p className="p-5 text-sm text-slate-500">No incidents recorded.</p>}
        {incidents && incidents.length > 0 && (
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Source
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Priority
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Detected
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Status
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {incidents.map((incident) => (
                <tr key={incident.id} className="hover:bg-slate-50">
                  <td className="px-5 py-3 text-sm font-medium text-navy">
                    <Link to={`/incidents/${incident.id}`}>{incident.source_type.replace(/_/g, " ")}</Link>
                  </td>
                  <td className="px-5 py-3 text-sm">
                    <Badge tone={priorityTone[incident.priority] ?? "neutral"}>{incident.priority}</Badge>
                  </td>
                  <td className="px-5 py-3 text-sm text-slate-700">
                    {new Date(incident.detected_at).toLocaleString()}
                  </td>
                  <td className="px-5 py-3 text-sm">
                    <IncidentStatusBadge status={incident.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
