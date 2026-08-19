import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { QRCodeSVG } from "qrcode.react";
import { ArrowLeft } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { getPack, quarantinePack, releasePack } from "@/features/packs/api";
import { PackStatusBadge } from "@/features/packs/PackStatusBadge";
import { EvidenceList } from "@/features/evidence/EvidenceList";
import { getCycle } from "@/features/cycles/api";
import { useAuth } from "@/contexts/AuthContext";

export function PackDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { hasRole } = useAuth();
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);

  const packQuery = useQuery({
    queryKey: ["packs", "detail", id],
    queryFn: () => getPack(id!),
    enabled: Boolean(id),
  });

  const cycleQuery = useQuery({
    queryKey: ["cycles", packQuery.data?.sterilization_cycle_id],
    queryFn: () => getCycle(packQuery.data!.sterilization_cycle_id),
    enabled: Boolean(packQuery.data?.sterilization_cycle_id),
  });

  const releaseMutation = useMutation({
    mutationFn: () => releasePack(id!),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["packs", "detail", id] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to release pack"),
  });

  const quarantineMutation = useMutation({
    mutationFn: (reason: string) => quarantinePack(id!, reason),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["packs", "detail", id] }),
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to quarantine pack"),
  });

  const pack = packQuery.data;
  const canRelease = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR", "CSSD_TECHNICIAN");
  const canQuarantine = hasRole("HOSPITAL_ADMIN", "CSSD_SUPERVISOR");

  if (packQuery.isLoading) return <p className="text-sm text-slate-500">Loading…</p>;
  if (!pack) return null;

  return (
    <div className="space-y-6">
      <Link
        to={`/cycles/${pack.sterilization_cycle_id}`}
        className="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700"
      >
        <ArrowLeft size={14} />
        Back to cycle
      </Link>

      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-slate-900">{pack.pack_code}</h1>
        <PackStatusBadge status={pack.status} />
      </div>

      {error && <p className="text-sm text-fail">{error}</p>}

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Pack QR Code</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col items-center gap-3">
            <div className="rounded-md border border-slate-200 p-4">
              <QRCodeSVG value={pack.qr_code} size={180} />
            </div>
            <p className="text-xs text-slate-400">{pack.qr_code}</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <Field label="Packed" value={new Date(pack.packed_at).toLocaleString()} />
            <Field label="Sterilized" value={pack.sterilized_at ? new Date(pack.sterilized_at).toLocaleString() : null} />
            <Field label="Expiry" value={pack.expiry_date ? new Date(pack.expiry_date).toLocaleDateString() : null} />

            {(canRelease || canQuarantine) && (
              <div className="flex gap-2 pt-2">
                {canRelease && pack.status === "PENDING_VERIFICATION" && cycleQuery.data?.cycle_status === "PASSED" && (
                  <Button disabled={releaseMutation.isPending} onClick={() => releaseMutation.mutate()}>
                    Release
                  </Button>
                )}
                {canQuarantine && ["PENDING_VERIFICATION", "RELEASED"].includes(pack.status) && (
                  <Button
                    variant="danger"
                    disabled={quarantineMutation.isPending}
                    onClick={() => {
                      const reason = window.prompt("Reason for quarantine:");
                      if (reason) quarantineMutation.mutate(reason);
                    }}
                  >
                    Quarantine
                  </Button>
                )}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Evidence</CardTitle>
        </CardHeader>
        <CardContent>
          <EvidenceList entityType="instrument_pack" entityId={pack.id} />
        </CardContent>
      </Card>
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
