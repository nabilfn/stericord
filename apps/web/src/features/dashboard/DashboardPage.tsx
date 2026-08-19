import { useQuery } from "@tanstack/react-query";
import { Wrench, ClipboardCheck, PackageCheck, AlertTriangle } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { listEquipment } from "@/features/equipment/api";
import { listCycles } from "@/features/cycles/api";
import { useAuth } from "@/contexts/AuthContext";

function isToday(isoDate: string) {
  const d = new Date(isoDate);
  const now = new Date();
  return d.toDateString() === now.toDateString();
}

export function DashboardPage() {
  const { profile } = useAuth();
  const { data: equipment } = useQuery({ queryKey: ["equipment"], queryFn: listEquipment });
  const { data: cycles } = useQuery({ queryKey: ["cycles"], queryFn: listCycles });

  const activeCount = equipment?.filter((e) => e.operating_status === "ACTIVE").length ?? 0;
  const lockedOutCount = equipment?.filter((e) => e.operating_status === "LOCKED_OUT").length ?? 0;

  const cyclesCompletedToday =
    cycles?.filter((c) => c.completed_at && isToday(c.completed_at) && ["PASSED", "FAILED", "COMPLETED", "PENDING_VERIFICATION"].includes(c.cycle_status)).length ?? 0;
  const openAlerts = cycles?.filter((c) => c.cycle_status === "FAILED" || c.cycle_status === "QUARANTINED").length ?? 0;

  const stats = [
    { label: "Cycles Completed Today", value: cyclesCompletedToday, icon: ClipboardCheck, note: `${cycles?.length ?? 0} total cycles` },
    { label: "Open Alerts", value: openAlerts, icon: PackageCheck, note: "Failed or quarantined cycles" },
    { label: "Active Equipment", value: activeCount, icon: Wrench, note: `${equipment?.length ?? 0} total` },
    { label: "Locked Out Equipment", value: lockedOutCount, icon: AlertTriangle, note: "Requires review" },
  ];

  const recentCycles = [...(cycles ?? [])]
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    .slice(0, 5);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">Dashboard</h1>
        <p className="text-sm text-slate-500">
          {profile ? `Welcome back, ${profile.full_name}.` : "Loading your workspace…"}
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map(({ label, value, icon: Icon, note }) => (
          <Card key={label}>
            <CardContent className="flex items-start justify-between">
              <div>
                <p className="text-xs font-medium uppercase tracking-wide text-slate-400">{label}</p>
                <p className="mt-1 text-2xl font-semibold text-slate-900">{value}</p>
                <p className="mt-1 text-xs text-slate-400">{note}</p>
              </div>
              <div className="rounded-md bg-sc-blue-light p-2 text-sc-blue">
                <Icon size={18} />
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Recent Cycles</CardTitle>
        </CardHeader>
        <CardContent>
          {recentCycles.length === 0 ? (
            <p className="text-sm text-slate-500">
              No cycles yet. OT point-of-use verification becomes available in Phase 3.
            </p>
          ) : (
            <ul className="divide-y divide-slate-100">
              {recentCycles.map((cycle) => (
                <li key={cycle.id} className="flex items-center justify-between py-2 text-sm">
                  <span className="font-medium text-slate-800">{cycle.cycle_number}</span>
                  <span className="text-slate-400">{cycle.cycle_status.replace(/_/g, " ")}</span>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
