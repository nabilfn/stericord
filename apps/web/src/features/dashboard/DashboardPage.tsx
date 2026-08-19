import { useQuery } from "@tanstack/react-query";
import { Wrench, ClipboardCheck, PackageCheck, AlertTriangle } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { listEquipment } from "@/features/equipment/api";
import { useAuth } from "@/contexts/AuthContext";

export function DashboardPage() {
  const { profile } = useAuth();
  const { data: equipment } = useQuery({ queryKey: ["equipment"], queryFn: listEquipment });

  const activeCount = equipment?.filter((e) => e.operating_status === "ACTIVE").length ?? 0;
  const lockedOutCount = equipment?.filter((e) => e.operating_status === "LOCKED_OUT").length ?? 0;

  const stats = [
    { label: "Cycles Completed Today", value: "—", icon: ClipboardCheck, note: "Available in Phase 2" },
    { label: "Packs Released Today", value: "—", icon: PackageCheck, note: "Available in Phase 2" },
    { label: "Active Equipment", value: activeCount, icon: Wrench, note: `${equipment?.length ?? 0} total` },
    { label: "Locked Out Equipment", value: lockedOutCount, icon: AlertTriangle, note: "Requires review" },
  ];

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
          <CardTitle>Recent Activity</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-slate-500">
            Sterilization cycles, pack tracking, and OT verifications become available in Phase 2 and Phase 3.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
