import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { MfaChallengePage } from "@/features/auth/MfaChallengePage";

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { session, loading, mfaChallengePending } = useAuth();

  if (loading) {
    return (
      <div className="flex h-screen w-screen items-center justify-center text-slate-500">
        Loading SteriCord…
      </div>
    );
  }

  if (!session) {
    return <Navigate to="/login" replace />;
  }

  if (mfaChallengePending) {
    return <MfaChallengePage />;
  }

  return <>{children}</>;
}
