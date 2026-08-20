import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { useAuth } from "@/contexts/AuthContext";
import { MfaSettings } from "@/features/auth/MfaSettings";

export function SettingsPage() {
  const { profile, roles } = useAuth();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">Settings</h1>
        <p className="text-sm text-slate-500">Your account and organization settings.</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-xs font-medium uppercase tracking-wide text-slate-400">Full name</p>
            <p className="text-slate-800">{profile?.full_name}</p>
          </div>
          <div>
            <p className="text-xs font-medium uppercase tracking-wide text-slate-400">Email</p>
            <p className="text-slate-800">{profile?.email}</p>
          </div>
          <div>
            <p className="text-xs font-medium uppercase tracking-wide text-slate-400">Roles</p>
            <p className="text-slate-800">{roles.join(", ") || "—"}</p>
          </div>
        </CardContent>
      </Card>

      <MfaSettings />

      <Card>
        <CardHeader>
          <CardTitle>About SteriCord</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-slate-500">
          Phase 8 — Offline, Security & Pilot Hardening.
        </CardContent>
      </Card>
    </div>
  );
}
