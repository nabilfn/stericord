import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { listPacksByCycle, quarantinePack, releasePack } from "@/features/packs/api";
import { PackStatusBadge } from "@/features/packs/PackStatusBadge";
import { Button } from "@/components/ui/Button";
import { useAuth } from "@/contexts/AuthContext";
import type { CycleStatus } from "@/types/database";

export function PackListForCycle({ cycleId, cycleStatus }: { cycleId: string; cycleStatus: CycleStatus }) {
  const { hasRole } = useAuth();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);

  const { data: packs } = useQuery({
    queryKey: ["packs", cycleId],
    queryFn: () => listPacksByCycle(cycleId),
  });

  const releaseMutation = useMutation({
    mutationFn: releasePack,
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["packs", cycleId] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to release pack"),
  });

  const quarantineMutation = useMutation({
    mutationFn: ({ packId, reason }: { packId: string; reason: string }) => quarantinePack(packId, reason),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["packs", cycleId] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to quarantine pack"),
  });

  const canRelease = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR", "CSSD_TECHNICIAN");
  const canQuarantine = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR");

  if (!packs || packs.length === 0) {
    return <p className="text-sm text-slate-500">No packs registered yet.</p>;
  }

  return (
    <div className="space-y-2">
      {error && <p className="text-sm text-fail">{error}</p>}
      <table className="min-w-full divide-y divide-slate-100">
        <thead>
          <tr className="text-left text-xs font-medium uppercase tracking-wide text-slate-500">
            <th className="py-2 pr-4">Pack code</th>
            <th className="py-2 pr-4">Status</th>
            <th className="py-2 pr-4">Expiry</th>
            <th className="py-2 pr-4"></th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {packs.map((pack) => (
            <tr key={pack.id}>
              <td className="py-2 pr-4 text-sm font-medium text-navy">
                <Link to={`/packs/${pack.id}`}>{pack.pack_code}</Link>
              </td>
              <td className="py-2 pr-4 text-sm">
                <PackStatusBadge status={pack.status} />
              </td>
              <td className="py-2 pr-4 text-sm text-slate-600">
                {pack.expiry_date ? new Date(pack.expiry_date).toLocaleDateString() : "—"}
              </td>
              <td className="py-2 pr-4 text-right">
                <div className="flex justify-end gap-2">
                  {canRelease && pack.status === "PENDING_VERIFICATION" && cycleStatus === "PASSED" && (
                    <Button
                      variant="secondary"
                      className="px-2 py-1 text-xs"
                      disabled={releaseMutation.isPending}
                      onClick={() => releaseMutation.mutate(pack.id)}
                    >
                      Release
                    </Button>
                  )}
                  {canQuarantine && ["PENDING_VERIFICATION", "RELEASED"].includes(pack.status) && (
                    <Button
                      variant="danger"
                      className="px-2 py-1 text-xs"
                      disabled={quarantineMutation.isPending}
                      onClick={() => {
                        const reason = window.prompt("Reason for quarantine:");
                        if (reason) quarantineMutation.mutate({ packId: pack.id, reason });
                      }}
                    >
                      Quarantine
                    </Button>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
