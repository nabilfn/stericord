-- SteriCord Phase 2: instrument sets (reference data for what a pack contains).

create table public.instrument_sets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  code text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

comment on table public.instrument_sets is 'Reference catalog of instrument set types, e.g. Major Ortho Tray, Minor Surgery Set.';

create index idx_instrument_sets_organization_id on public.instrument_sets(organization_id);

create trigger trg_instrument_sets_updated_at
  before update on public.instrument_sets
  for each row execute function public.set_updated_at();

alter table public.instrument_sets enable row level security;

create policy instrument_sets_select on public.instrument_sets
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy instrument_sets_insert on public.instrument_sets
  for insert
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR']::public.user_role[])
    or public.is_system_admin()
  );

create policy instrument_sets_update on public.instrument_sets
  for update
  using (
    organization_id = public.current_organization_id()
    and (
      public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR']::public.user_role[])
      or public.is_system_admin()
    )
  )
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR']::public.user_role[])
    or public.is_system_admin()
  );
