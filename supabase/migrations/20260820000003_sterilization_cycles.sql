-- SteriCord Phase 2: sterilization cycles.
-- Direct client UPDATEs are intentionally NOT granted via RLS: cycle_status
-- changes (and the cascading effects on instrument_packs) only happen
-- through the security-definer workflow functions in
-- 20260820000006_cssd_workflow_functions.sql, so the state machine can't be
-- bypassed by a client PATCH. Only INSERT (create) and SELECT are exposed
-- directly.

create table public.sterilization_cycles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  equipment_id uuid not null references public.equipment(id) on delete restrict,
  cycle_number text not null,
  cycle_type text not null,
  started_at timestamptz,
  completed_at timestamptz,
  temperature numeric,
  pressure numeric,
  hold_time_seconds integer,
  operator_user_id uuid references public.profiles(id) on delete set null,
  cycle_status public.cycle_status not null default 'CREATED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, cycle_number)
);

comment on table public.sterilization_cycles is 'One autoclave/washer run. cycle_status only changes via the workflow functions, never a direct client UPDATE.';

create index idx_sterilization_cycles_organization_id on public.sterilization_cycles(organization_id);
create index idx_sterilization_cycles_equipment_id on public.sterilization_cycles(equipment_id);
create index idx_sterilization_cycles_status on public.sterilization_cycles(cycle_status);

create trigger trg_sterilization_cycles_updated_at
  before update on public.sterilization_cycles
  for each row execute function public.set_updated_at();

create table public.cycle_parameters (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cycle_id uuid not null references public.sterilization_cycles(id) on delete cascade,
  recorded_at timestamptz not null default now(),
  temperature numeric,
  pressure numeric,
  notes text,
  recorded_by uuid references public.profiles(id) on delete set null
);

comment on table public.cycle_parameters is 'Optional time-series parameter readings for a cycle, in addition to the cycle-level summary values.';

create index idx_cycle_parameters_cycle_id on public.cycle_parameters(cycle_id);

alter table public.sterilization_cycles enable row level security;
alter table public.cycle_parameters enable row level security;

create policy sterilization_cycles_select on public.sterilization_cycles
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy sterilization_cycles_insert on public.sterilization_cycles
  for insert
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'CSSD_TECHNICIAN']::public.user_role[])
    or public.is_system_admin()
  );

create policy cycle_parameters_select on public.cycle_parameters
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy cycle_parameters_insert on public.cycle_parameters
  for insert
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'CSSD_TECHNICIAN']::public.user_role[])
    or public.is_system_admin()
  );
