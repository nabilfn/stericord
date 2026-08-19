-- SteriCord Phase 1: equipment registry and status history
-- Master prompt section 17: "Do not erase status history" -- status changes
-- are appended to equipment_status_events by trigger, never overwritten.

create type public.equipment_type as enum (
  'STEAM_AUTOCLAVE',
  'ETO_STERILIZER',
  'PLASMA_STERILIZER',
  'WASHER_DISINFECTOR',
  'ULTRASONIC_CLEANER',
  'OTHER'
);

create table public.equipment (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  department_id uuid references public.departments(id) on delete set null,
  equipment_code text not null,
  equipment_type public.equipment_type not null,
  manufacturer text,
  model_name text,
  serial_number text,
  location text,
  operating_status public.equipment_status not null default 'ACTIVE',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, equipment_code)
);

comment on table public.equipment is 'Sterilization / decontamination equipment registry, one row per physical unit.';

create index idx_equipment_organization_id on public.equipment(organization_id);
create index idx_equipment_department_id on public.equipment(department_id);
create index idx_equipment_operating_status on public.equipment(operating_status);

create trigger trg_equipment_updated_at
  before update on public.equipment
  for each row execute function public.set_updated_at();

create table public.equipment_status_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  equipment_id uuid not null references public.equipment(id) on delete cascade,
  previous_status public.equipment_status,
  new_status public.equipment_status not null,
  reason text,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);

comment on table public.equipment_status_events is 'Append-only history of equipment.operating_status transitions. Never updated or deleted by the application.';

create index idx_equipment_status_events_equipment_id on public.equipment_status_events(equipment_id);
create index idx_equipment_status_events_organization_id on public.equipment_status_events(organization_id);

create or replace function public.record_equipment_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or old.operating_status is distinct from new.operating_status then
    insert into public.equipment_status_events (
      organization_id, equipment_id, previous_status, new_status, changed_by
    ) values (
      new.organization_id,
      new.id,
      case when tg_op = 'INSERT' then null else old.operating_status end,
      new.operating_status,
      auth.uid()
    );
  end if;
  return new;
end;
$$;

create trigger trg_equipment_status_insert
  after insert on public.equipment
  for each row execute function public.record_equipment_status_change();

create trigger trg_equipment_status_update
  after update of operating_status on public.equipment
  for each row execute function public.record_equipment_status_change();

-- RLS ---------------------------------------------------------------------------

alter table public.equipment enable row level security;
alter table public.equipment_status_events enable row level security;

create policy equipment_select on public.equipment
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy equipment_insert on public.equipment
  for insert
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'BIOMEDICAL_ENGINEER']::public.user_role[])
    or public.is_system_admin()
  );

create policy equipment_update on public.equipment
  for update
  using (
    organization_id = public.current_organization_id()
    and (
      public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'BIOMEDICAL_ENGINEER']::public.user_role[])
      or public.is_system_admin()
    )
  )
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'BIOMEDICAL_ENGINEER']::public.user_role[])
    or public.is_system_admin()
  );

-- equipment_status_events is append-only: select policy only, no update/delete,
-- insert happens exclusively via the security-definer trigger above.
create policy equipment_status_events_select on public.equipment_status_events
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );
