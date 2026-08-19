-- SteriCord Phase 3: incidents.
-- Master prompt section 26: "Do not reduce incident handling to a single
-- boolean" -- the full 9-state status enum is exposed, not a pass/fail flag.
-- Rows are created only by record_point_of_use_verification() (an OT
-- failure) or open_incident() (a manual report); status only advances
-- through advance_incident_status()/resolve_incident(), never a direct
-- client UPDATE.

create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_type text not null,
  related_entity_type text not null,
  related_entity_id uuid,
  point_of_use_record_id uuid references public.point_of_use_records(id) on delete set null,
  status public.incident_status not null default 'DETECTED',
  priority public.incident_priority not null default 'MEDIUM',
  description text,
  detected_by uuid references public.profiles(id) on delete set null,
  detected_at timestamptz not null default now(),
  acknowledged_by uuid references public.profiles(id) on delete set null,
  acknowledged_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.incidents is 'A tracked safety event, e.g. an OT point-of-use verification failure. status is never a boolean.';

create index idx_incidents_organization_id on public.incidents(organization_id);
create index idx_incidents_status on public.incidents(status);
create index idx_incidents_related_entity on public.incidents(related_entity_type, related_entity_id);

create trigger trg_incidents_updated_at
  before update on public.incidents
  for each row execute function public.set_updated_at();

alter table public.incidents enable row level security;

create policy incidents_select on public.incidents
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );
