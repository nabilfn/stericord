-- SteriCord Phase 4: image quality metadata on captured evidence.
-- Master prompt section 33: blur / exposure / glare checks run client-side
-- (in the browser via Canvas pixel data, and in Flutter via the `image`
-- package) before a file is ever uploaded -- a RETAKE_REQUIRED photo is
-- never sent to storage, so these columns only ever describe an ACCEPTED
-- capture. They exist so the acceptance decision is itself auditable
-- (what score let this through) and so Phase 6+ has quality metadata
-- alongside each image from day one, per section 37.
--
-- "Do not rely on one universal hard-coded blur threshold" -- thresholds
-- are chosen per evidence_type in application code, not encoded here.

create type public.evidence_quality_status as enum ('ACCEPTED', 'RETAKE_REQUIRED');

create type public.evidence_quality_reason as enum (
  'IMAGE_TOO_BLURRY',
  'IMAGE_TOO_DARK',
  'GLARE_DETECTED',
  'INDICATOR_NOT_IN_FRAME'
);

alter table public.evidence_files
  add column quality_status public.evidence_quality_status,
  add column quality_reasons public.evidence_quality_reason[] not null default '{}',
  add column blur_score numeric,
  add column brightness_score numeric,
  add column glare_ratio numeric;

comment on column public.evidence_files.quality_status is 'Client-computed at capture time. Null for evidence captured before Phase 4.';
comment on column public.evidence_files.quality_reasons is 'Populated only if a client ever uploads despite a non-ACCEPTED assessment (defense in depth) -- normally empty, since RETAKE_REQUIRED blocks upload client-side.';
