-- SteriCord Phase 1: RLS helper functions
-- security definer + stable so policies can call these without triggering
-- recursive RLS evaluation on profiles/user_roles themselves.

create or replace function public.current_organization_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select organization_id from public.profiles where id = auth.uid();
$$;

create or replace function public.user_has_role(target_org uuid, roles public.user_role[])
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.organization_id = target_org
      and ur.role = any(roles)
      and ur.revoked_at is null
  );
$$;

create or replace function public.is_system_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role = 'SYSTEM_ADMIN'
      and ur.revoked_at is null
  );
$$;

comment on function public.current_organization_id() is 'Home organization of the calling user, used as the tenant boundary in RLS policies.';
comment on function public.user_has_role(uuid, public.user_role[]) is 'True if the calling user currently holds one of the given roles within target_org.';
comment on function public.is_system_admin() is 'True if the calling user holds an active SYSTEM_ADMIN grant in any organization; system admins can cross tenant boundaries.';
