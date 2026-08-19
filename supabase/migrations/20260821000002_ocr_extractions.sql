-- SteriCord Phase 5: OCR / Document AI extractions.
-- Master prompt section 34: "Do not make OCR output authoritative without
-- review." extracted_fields is what Document AI (or its regex-based field
-- parsing over the recognized text, in the absence of a custom-trained
-- entity extractor) produced; human_confirmed_fields is the separate,
-- authoritative column a person actually reviewed and saved via
-- confirm_ocr_extraction(). Nothing in the rest of the schema ever reads
-- extracted_fields directly -- only human_confirmed_fields is meant to feed
-- back into cycle data.

create type public.ocr_extraction_status as enum ('COMPLETED', 'FAILED', 'NOT_CONFIGURED');

alter type public.audit_event_type add value if not exists 'OCR_EXTRACTION_REQUESTED';
alter type public.audit_event_type add value if not exists 'OCR_EXTRACTION_COMPLETED';
alter type public.audit_event_type add value if not exists 'OCR_EXTRACTION_CONFIRMED';

create table public.ocr_extractions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  evidence_file_id uuid not null references public.evidence_files(id) on delete cascade,
  provider text not null default 'google_document_ai',
  status public.ocr_extraction_status not null,
  raw_text text,
  extracted_fields jsonb not null default '{}'::jsonb,
  confidence numeric,
  error_message text,
  human_confirmed_fields jsonb,
  confirmed_by uuid references public.profiles(id) on delete set null,
  confirmed_at timestamptz,
  requested_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.ocr_extractions is 'One OCR attempt against one evidence file. Rows are written by the ocr-extract edge function (service role) and confirmed by confirm_ocr_extraction() -- never a direct client INSERT/UPDATE.';

create index idx_ocr_extractions_organization_id on public.ocr_extractions(organization_id);
create index idx_ocr_extractions_evidence_file_id on public.ocr_extractions(evidence_file_id);

alter table public.ocr_extractions enable row level security;

create policy ocr_extractions_select on public.ocr_extractions
  for select
  using (
    organization_id = public.current_organization_id()
    or public.is_system_admin()
  );

create or replace function public.confirm_ocr_extraction(p_extraction_id uuid, p_confirmed_fields jsonb)
returns public.ocr_extractions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_extraction public.ocr_extractions;
begin
  select * into v_extraction from public.ocr_extractions where id = p_extraction_id;
  if v_extraction is null then
    raise exception 'OCR extraction % not found', p_extraction_id;
  end if;
  if v_extraction.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_extraction.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR','CSSD_TECHNICIAN']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to confirm an OCR extraction';
  end if;

  update public.ocr_extractions
  set human_confirmed_fields = p_confirmed_fields, confirmed_by = auth.uid(), confirmed_at = now()
  where id = p_extraction_id
  returning * into v_extraction;

  perform public.log_audit_event(
    v_extraction.organization_id, 'OCR_EXTRACTION_CONFIRMED', 'ocr_extraction', p_extraction_id,
    null, p_confirmed_fields
  );

  return v_extraction;
end;
$$;
