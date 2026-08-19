-- SteriCord Phase 2: evidence metadata + storage.
-- Binary files live in Supabase Storage (private bucket "evidence"); this
-- table only holds metadata + a client-computed sha256 hash. Storage object
-- paths follow "{organization_id}/{entity_type}/{entity_id}/{filename}" so a
-- single reusable storage.objects RLS policy can enforce tenant isolation by
-- reading the first path segment.

create table public.evidence_files (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  storage_provider text not null default 'supabase',
  bucket text not null default 'evidence',
  object_path text not null,
  file_type text,
  mime_type text,
  file_size bigint,
  sha256_hash text,
  evidence_type public.evidence_type not null,
  captured_by uuid references public.profiles(id) on delete set null,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (bucket, object_path)
);

comment on table public.evidence_files is 'Metadata for evidence images/documents (autoclave receipts, Bowie-Dick, etc). Binary content lives in Supabase Storage.';

create index idx_evidence_files_organization_id on public.evidence_files(organization_id);
create index idx_evidence_files_entity on public.evidence_files(entity_type, entity_id);

alter table public.evidence_files enable row level security;

create policy evidence_files_select on public.evidence_files
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create policy evidence_files_insert on public.evidence_files
  for insert
  with check (
    public.user_has_role(organization_id, array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'CSSD_TECHNICIAN', 'OT_NURSE']::public.user_role[])
    or public.is_system_admin()
  );

-- Storage RLS: tenant isolation on the "evidence" bucket by first path segment.

create policy evidence_bucket_select on storage.objects
  for select
  using (
    bucket_id = 'evidence'
    and (
      (storage.foldername(name))[1] = public.current_organization_id()::text
      or public.is_system_admin()
    )
  );

create policy evidence_bucket_insert on storage.objects
  for insert
  with check (
    bucket_id = 'evidence'
    and (
      (storage.foldername(name))[1] = public.current_organization_id()::text
      or public.is_system_admin()
    )
  );
