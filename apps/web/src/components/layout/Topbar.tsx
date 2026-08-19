import { LogOut } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/Button";

export function Topbar() {
  const { profile, roles, signOut } = useAuth();

  return (
    <header className="flex h-16 shrink-0 items-center justify-between border-b border-slate-200 bg-white px-6">
      <div />
      <div className="flex items-center gap-4">
        <div className="text-right">
          <p className="text-sm font-medium text-slate-900">{profile?.full_name}</p>
          <p className="text-xs text-slate-500">{roles.join(", ") || "No role assigned"}</p>
        </div>
        <Button variant="ghost" onClick={() => void signOut()}>
          <LogOut size={16} />
          Sign out
        </Button>
      </div>
    </header>
  );
}
