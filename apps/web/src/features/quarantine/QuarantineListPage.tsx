import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { useAuth } from "@/contexts/AuthContext";
import { listQuarantines, releaseQuarantine } from "@/features/quarantine/api";

export function QuarantineListPage() {
  const { hasRole } = useAuth();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);

  const { data: quarantines, isLoading } = useQuery({
    queryKey: ["quarantines"],
    queryFn: listQuarantines,
  });

  const releaseMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => releaseQuarantine(id, reason),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["quarantines"] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to release quarantine"),
  });

  const canRelease = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR");

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">Quarantine</h1>
        <p className="text-sm text-slate-500">
          Active holds on packs, cycles, and batches. Releasing a quarantine documents that the investigation
          concluded — it does not return the item to service.
        </p>
      </div>

      {error && <p className="text-sm text-fail">{error}</p>}

      <Card className="overflow-hidden">
        {isLoading && <p className="p-5 text-sm text-slate-500">Loading quarantines…</p>}
        {quarantines && quarantines.length === 0 && (
          <p className="p-5 text-sm text-slate-500">No quarantines recorded.</p>
        )}
        {quarantines && quarantines.length > 0 && (
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Scope
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Reason
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Initiated
                </th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">
                  Status
                </th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {quarantines.map((q) => (
                <tr key={q.id} className="hover:bg-slate-50">
                  <td className="px-5 py-3 text-sm font-medium text-slate-900">{q.scope_type}</td>
                  <td className="px-5 py-3 text-sm text-slate-700">{q.reason}</td>
                  <td className="px-5 py-3 text-sm text-slate-700">{new Date(q.initiated_at).toLocaleString()}</td>
                  <td className="px-5 py-3 text-sm">
                    <Badge tone={q.status === "ACTIVE" ? "fail" : "neutral"}>{q.status}</Badge>
                  </td>
                  <td className="px-5 py-3 text-right">
                    {canRelease && q.status === "ACTIVE" && (
                      <Button
                        variant="secondary"
                        className="px-2 py-1 text-xs"
                        disabled={releaseMutation.isPending}
                        onClick={() => {
                          const reason = window.prompt("Release reason:");
                          if (reason) releaseMutation.mutate({ id: q.id, reason });
                        }}
                      >
                        Release
                      </Button>
                    )}
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
