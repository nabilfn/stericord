import { supabase } from "@/services/supabaseClient";
import type { Profile, UserRoleGrant } from "@/types/database";

export interface ProfileWithRoles extends Profile {
  roles: UserRoleGrant[];
}

export async function listOrganizationUsers(): Promise<ProfileWithRoles[]> {
  const { data: profiles, error: profilesError } = await supabase
    .from("profiles")
    .select("*")
    .order("full_name", { ascending: true });
  if (profilesError) throw profilesError;

  const { data: roles, error: rolesError } = await supabase
    .from("user_roles")
    .select("*")
    .is("revoked_at", null);
  if (rolesError) throw rolesError;

  const rolesByUser = new Map<string, UserRoleGrant[]>();
  for (const role of (roles ?? []) as UserRoleGrant[]) {
    const existing = rolesByUser.get(role.user_id) ?? [];
    existing.push(role);
    rolesByUser.set(role.user_id, existing);
  }

  return ((profiles ?? []) as Profile[]).map((profile) => ({
    ...profile,
    roles: rolesByUser.get(profile.id) ?? [],
  }));
}
