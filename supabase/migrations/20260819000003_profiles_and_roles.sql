-- SteriCord Phase 1: profiles and role assignments
-- profiles is 1:1 with auth.users. user_roles is a separate table because a
-- user may hold more than one role (master prompt section 15) and because
-- role history should be preserved instead of overwritten.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  department_id uuid references public.departments(id) on delete set null,
  full_name text not null,
  email text not null,
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Application-level user profile, one row per auth.users entry, scoped to a single home organization.';

create index idx_profiles_organization_id on public.profiles(organization_id);
create index idx_profiles_department_id on public.profiles(department_id);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  role public.user_role not null,
  granted_by uuid references public.profiles(id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz
);

comment on table public.user_roles is 'Role grants for a user within an organization. Revocation is recorded, not deleted, to preserve history.';

create index idx_user_roles_user_id on public.user_roles(user_id);
create index idx_user_roles_organization_id on public.user_roles(organization_id);

-- A user can only hold a given role once at a time (re-granting after
-- revocation is allowed and creates a new row).
create unique index uq_user_roles_active_grant
  on public.user_roles(user_id, organization_id, role)
  where revoked_at is null;

-- Auto-provision a profile row when a new auth.users record is created.
-- Expects organization_id and full_name to be supplied via
-- raw_user_meta_data at sign-up time (set by an admin invite flow).
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, organization_id, department_id, full_name, email)
  values (
    new.id,
    (new.raw_user_meta_data->>'organization_id')::uuid,
    nullif(new.raw_user_meta_data->>'department_id', '')::uuid,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.email
  );
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
