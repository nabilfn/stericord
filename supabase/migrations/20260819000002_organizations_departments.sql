-- SteriCord Phase 1: organizations (hospitals) and departments
-- Master prompt section 14: multi-tenancy from day one, organization_id on
-- every operational record.

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.organizations is 'A hospital / tenant. Root of all multi-tenant isolation.';

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  code text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

comment on table public.departments is 'Department within a hospital, e.g. CSSD, OT, Ward 3B.';

create index idx_departments_organization_id on public.departments(organization_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_organizations_updated_at
  before update on public.organizations
  for each row execute function public.set_updated_at();

create trigger trg_departments_updated_at
  before update on public.departments
  for each row execute function public.set_updated_at();
