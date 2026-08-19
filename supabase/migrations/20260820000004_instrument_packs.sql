-- SteriCord Phase 2: instrument packs.
-- Like sterilization_cycles, pack_status only changes via the workflow
-- functions -- no direct client UPDATE is granted. INSERT is allowed while
-- registering packs into a cycle that hasn't completed yet, enforced by a
-- BEFORE INSERT trigger (cross-table checks belong in a trigger, not RLS,
-- since a single-table USING/WITH CHECK clause can't see the parent cycle).

create table public.instrument_packs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  instrument_set_id uuid not null references public.instrument_sets(id) on delete restrict,
  sterilization_cycle_id uuid not null references public.sterilization_cycles(id) on delete restrict,
  pack_code text not null,
  qr_code text not null default replace(gen_random_uuid()::text, '-', ''),
  packed_at timestamptz not null default now(),
  sterilized_at timestamptz,
  expiry_date date,
  status public.pack_status not null default 'PACKED',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, pack_code),
  unique (qr_code)
);

comment on table public.instrument_packs is 'A physical pack of instruments sterilized as part of one cycle. qr_code is an opaque token, not the row id, so it can be reprinted/rotated without exposing internal structure.';

create index idx_instrument_packs_organization_id on public.instrument_packs(organization_id);
create index idx_instrument_packs_cycle_id on public.instrument_packs(sterilization_cycle_id);
create index idx_instrument_packs_status on public.instrument_packs(status);
create index idx_instrument_packs_qr_code on public.instrument_packs(qr_code);

create trigger trg_instrument_packs_updated_at
  before update on public.instrument_packs
  for each row execute function public.set_updated_at();

create or replace function public.check_pack_insert_against_cycle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.sterilization_cycles;
begin
  select * into v_cycle from public.sterilization_cycles where id = new.sterilization_cycle_id;

  if v_cycle is null then
    raise exception 'Sterilization cycle % not found', new.sterilization_cycle_id;
  end if;

  if v_cycle.organization_id <> new.organization_id then
    raise exception 'Pack organization_id must match the cycle organization_id';
  end if;

  if v_cycle.cycle_status not in ('CREATED', 'RUNNING') then
    raise exception 'Packs can only be registered while the cycle is CREATED or RUNNING (current status: %)', v_cycle.cycle_status;
  end if;

  if new.status <> 'PACKED' then
    raise exception 'New packs must start in PACKED status';
  end if;

  return new;
end;
$$;

create trigger trg_check_pack_insert_against_cycle
  before insert on public.instrument_packs
  for each row execute function public.check_pack_insert_against_cycle();

alter table public.instrument_packs enable row level security;

create policy instrument_packs_select on public.instrument_packs
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy instrument_packs_insert on public.instrument_packs
  for insert
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'CSSD_TECHNICIAN']::public.user_role[])
    or public.is_system_admin()
  );
