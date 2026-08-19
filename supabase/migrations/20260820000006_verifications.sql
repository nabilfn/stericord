-- SteriCord Phase 2: verifications.
-- Rows are inserted only by public.verify_cycle() (next migration), which
-- also drives the cycle_status/pack_status transitions. No direct INSERT is
-- granted so a client can't record a "verification" that never actually
-- changed cycle state -- AI fields are unused until Phase 6 but present now
-- so the shape doesn't change later.

create table public.verifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  verification_type text not null,
  ai_suggested_result public.verification_result,
  ai_confidence numeric,
  human_result public.verification_result not null,
  verified_by uuid not null references public.profiles(id) on delete restrict,
  verified_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

comment on table public.verifications is 'Human (and later AI-assisted) verification decisions. ai_* columns stay null until Phase 6.';

create index idx_verifications_organization_id on public.verifications(organization_id);
create index idx_verifications_entity on public.verifications(entity_type, entity_id);

alter table public.verifications enable row level security;

create policy verifications_select on public.verifications
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );
