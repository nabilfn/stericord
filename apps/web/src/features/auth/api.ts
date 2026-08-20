import { supabase } from "@/services/supabaseClient";
import type { Profile, UserRoleGrant } from "@/types/database";

export async function signInWithPassword(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function fetchCurrentProfile(userId: string): Promise<Profile> {
  const { data, error } = await supabase.from("profiles").select("*").eq("id", userId).single();
  if (error) throw error;
  return data as Profile;
}

export async function fetchActiveRoles(userId: string, organizationId: string): Promise<UserRoleGrant[]> {
  const { data, error } = await supabase
    .from("user_roles")
    .select("*")
    .eq("user_id", userId)
    .eq("organization_id", organizationId)
    .is("revoked_at", null);
  if (error) throw error;
  return (data ?? []) as UserRoleGrant[];
}

export async function getAuthenticatorAssuranceLevel() {
  const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (error) throw error;
  return data;
}

export async function listMfaFactors() {
  const { data, error } = await supabase.auth.mfa.listFactors();
  if (error) throw error;
  return data.totp;
}

export async function enrollMfaFactor() {
  const { data, error } = await supabase.auth.mfa.enroll({ factorType: "totp" });
  if (error) throw error;
  return data;
}

export async function challengeAndVerifyMfaFactor(factorId: string, code: string) {
  const { data, error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
  if (error) throw error;
  return data;
}

export async function unenrollMfaFactor(factorId: string) {
  const { error } = await supabase.auth.mfa.unenroll({ factorId });
  if (error) throw error;
}
