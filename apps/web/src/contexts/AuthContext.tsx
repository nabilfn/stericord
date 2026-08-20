import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/services/supabaseClient";
import {
  fetchActiveRoles,
  fetchCurrentProfile,
  getAuthenticatorAssuranceLevel,
  signInWithPassword,
  signOut as signOutRequest,
} from "@/features/auth/api";
import type { Profile, UserRole } from "@/types/database";

interface AuthContextValue {
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  roles: UserRole[];
  loading: boolean;
  /** True once signed in but a verified MFA factor still needs a fresh challenge this session. */
  mfaChallengePending: boolean;
  hasRole: (...allowed: UserRole[]) => boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  refreshMfaStatus: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [roles, setRoles] = useState<UserRole[]>([]);
  const [loading, setLoading] = useState(true);
  const [mfaChallengePending, setMfaChallengePending] = useState(false);

  async function loadProfileAndRoles(userId: string) {
    const nextProfile = await fetchCurrentProfile(userId);
    setProfile(nextProfile);
    const grants = await fetchActiveRoles(userId, nextProfile.organization_id);
    setRoles(grants.map((g) => g.role));
  }

  async function refreshMfaStatus() {
    const aal = await getAuthenticatorAssuranceLevel();
    setMfaChallengePending(aal.nextLevel === "aal2" && aal.currentLevel !== aal.nextLevel);
  }

  useEffect(() => {
    let active = true;

    supabase.auth.getSession().then(async ({ data }) => {
      if (!active) return;
      setSession(data.session);
      if (data.session?.user) {
        await loadProfileAndRoles(data.session.user.id);
        await refreshMfaStatus();
      }
      setLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange(async (_event, nextSession) => {
      setSession(nextSession);
      if (nextSession?.user) {
        setLoading(true);
        await loadProfileAndRoles(nextSession.user.id);
        await refreshMfaStatus();
        setLoading(false);
      } else {
        setProfile(null);
        setRoles([]);
        setMfaChallengePending(false);
      }
    });

    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  async function signIn(email: string, password: string) {
    await signInWithPassword(email, password);
  }

  async function signOut() {
    await signOutRequest();
  }

  function hasRole(...allowed: UserRole[]) {
    return roles.some((r) => allowed.includes(r));
  }

  const value: AuthContextValue = {
    session,
    user: session?.user ?? null,
    profile,
    roles,
    loading,
    mfaChallengePending,
    hasRole,
    signIn,
    signOut,
    refreshMfaStatus,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within an AuthProvider");
  return ctx;
}
