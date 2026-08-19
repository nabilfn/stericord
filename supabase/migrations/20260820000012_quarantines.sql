-- SteriCord Phase 3: quarantines.
-- scope_id is intentionally polymorphic (points at instrument_packs.id
-- today, could point at a cycle/batch/equipment group later per
-- scope_type) so there is no FK constraint on it -- validity is enforced in
-- the functions that create rows, not the schema.

create table public.quarantines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_incident_id uuid references public.incidents(id) on delete set null,
  scope_type public.quarantine_scope not null,
  scope_id uuid not null,
  reason text not null,
  status public.quarantine_status not null default 'ACTIVE',
  initiated_by uuid references public.profiles(id) on delete set null,
  initiated_at timestamptz not null default now(),
  released_by uuid references public.profiles(id) on delete set null,
  released_at timestamptz,
  release_reason text
);

comment on table public.quarantines is 'A hold placed on a pack/cycle/batch/equipment group. Releasing a quarantine documents that an investigation concluded -- it does not, by itself, put a quarantined pack back into service.';

create index idx_quarantines_organization_id on public.quarantines(organization_id);
create index idx_quarantines_scope on public.quarantines(scope_type, scope_id);
create index idx_quarantines_status on public.quarantines(status);

alter table public.quarantines enable row level security;

create policy quarantines_select on public.quarantines
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );
