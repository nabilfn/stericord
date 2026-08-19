-- SteriCord Phase 3: OT / ward point-of-use verification records.
-- Master prompt section 25: prefer external patient/encounter references,
-- avoid unnecessary patient demographics -- both fields here are opaque
-- free-text references into an external system, never names/DOB/etc.
-- Rows are written only by public.record_point_of_use_verification()
-- (next migration); no direct client INSERT is granted, matching the
-- cycle/pack workflow-function pattern from Phase 2.

create table public.point_of_use_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  pack_id uuid not null references public.instrument_packs(id) on delete restrict,
  department_id uuid references public.departments(id) on delete set null,
  patient_reference text,
  encounter_reference text,
  eligibility_passed boolean not null,
  eligibility_reason text,
  verification_result public.verification_result not null,
  notes text,
  scanned_by uuid not null references public.profiles(id) on delete restrict,
  scanned_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

comment on table public.point_of_use_records is 'One scan-and-verify event of a pack at OT/ward point of use.';

create index idx_point_of_use_records_organization_id on public.point_of_use_records(organization_id);
create index idx_point_of_use_records_pack_id on public.point_of_use_records(pack_id);

alter table public.point_of_use_records enable row level security;

create policy point_of_use_records_select on public.point_of_use_records
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );
