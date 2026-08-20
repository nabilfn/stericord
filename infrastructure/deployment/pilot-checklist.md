# Pilot deployment checklist

Master prompt section 41's "Pilot deployment configuration." This is the
concrete list to work through before a real hospital's CSSD/OT staff start
using SteriCord, not a restatement of the architecture -- see
`docs/architecture/` for how each piece works.

## Before day one

- [ ] **Supabase project provisioned** (not local CLI) -- run every
      migration in `supabase/migrations/` against it in order, then run
      `infrastructure/deployment/security-checks.sh` against the real
      project (pass its host/port/API URL as arguments) to confirm RLS,
      write-path, and storage-privacy behavior holds outside the local dev
      stack too.
- [ ] **MFA enforced for admin/supervisor roles.** Enrollment is
      self-service today (Settings -> "Enable two-factor authentication");
      for a pilot, HOSPITAL_ADMIN and CSSD_SUPERVISOR accounts should
      enroll before go-live, since those roles can verify cycles and
      release quarantines.
- [ ] **Real credentials for Document AI and Gemini**, or an explicit
      decision to run the pilot without them (OCR/AI both degrade to a
      manual-entry `NOT_CONFIGURED` path if absent -- see
      `docs/architecture/phase-5-ocr.md` / `phase-6-multimodal-ai.md` --
      which is a legitimate pilot choice, not a broken deployment, but
      should be a deliberate one).
- [ ] **Storage provider decision.** Section 22's abstraction defaults to
      Supabase Storage; if the hospital's IT requires a specific provider
      (S3, Azure Blob, on-prem MinIO) for data-residency reasons, that
      needs its own credentials in the root `.env` before evidence capture
      starts, not after.
- [ ] **Backup schedule wired up.** `infrastructure/deployment/backup-db.sh`
      works today when run manually (verified against the local stack: a
      real dump, a real restore, correct row counts) -- for a pilot it
      needs to run on an actual schedule (cron / hosted scheduler) with the
      output shipped somewhere other than the same disk as the database.
- [ ] **Retention/reporting sign-off.** `evidence_files` and `audit_events`
      already stamp `retention_expires_at` at 7 years on insert (section
      23); nothing reads or acts on it yet (Phase 7's scope explicitly
      stopped short of an archival job). Confirm the pilot's compliance
      contact is aware retention is *tracked*, not yet *enforced*.

## Known gaps going into a pilot (be upfront about these)

- **Mobile app is unverified.** Every Flutter file in `apps/mobile/`,
  including this phase's offline queue (`lib/core/offline/`), was written
  against the same conventions as the rest of the app but never compiled
  or run -- this sandboxed environment has no Flutter SDK. Before a device
  ever leaves the CSSD for a pilot, someone needs to `flutter pub get`,
  `flutter analyze`, and run the app against a real device or simulator
  for the first time, starting with the offline queue: kill the app
  mid-sync, confirm the interrupted record recovers instead of hanging in
  `SYNCING` forever, and confirm a retried sync doesn't duplicate a
  point-of-use record (the server-side idempotency this relies on --
  `client_operation_log` -- is verified; the client side calling it
  correctly on a real device is not).
- **Device testing has not happened at all** -- no physical Android/iOS
  hardware, camera, or QR scanner has touched this build. Camera
  permissions, QR scan reliability under OT lighting, and the image
  quality gate's real-world false-positive/negative rate all need
  hands-on testing before staff rely on them clinically.
- **Offline sync only covers OT point-of-use.** CSSD cycle functions
  (`start_cycle`, `complete_cycle`, etc.) assume connectivity, matching
  the assumption that the sterilizer room has reliable wifi. If a pilot
  site's CSSD does not, that gap needs to be closed before go-live there
  specifically.
- **Monitoring is not wired to a real APM/alerting backend.** The
  reporting service and Supabase both produce structured logs today
  (uvicorn access logs, Postgres logs), but nothing ships them to
  Sentry/Datadog/equivalent or pages anyone on failure -- there are no
  real credentials for one in this environment. Decide on a provider and
  wire it before a pilot depends on someone noticing an outage.
- **Load testing was a local smoke test, not pilot-scale.** See
  `docs/architecture/phase-8-offline-security-pilot.md` for the actual
  numbers measured (single machine, local stack) -- reasonable as a
  regression baseline, not a capacity guarantee for concurrent pilot-site
  traffic.

## Rollback plan

Every state-changing write goes through a SECURITY DEFINER function or an
audited insert -- there is no direct client UPDATE path to work around if
something needs correcting by hand (see `docs/architecture/phase-2-cssd-core.md`
for why). If a pilot needs to be rolled back:

1. Stop accepting new writes (revoke pilot users' sessions, or point the
   app at a read-only replica if one exists).
2. Take a final backup with `backup-db.sh` before touching anything.
3. Any correction to already-written data should go through
   `log_audit_event` too, even for a manual fix -- an unaudited correction
   defeats the entire premise of `verify_audit_chain()`.
