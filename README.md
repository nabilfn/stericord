# SteriCord

Hospital sterilization traceability and assurance platform. See
[SteriCord_Updated_Master_Development_Prompt.md](./SteriCord_Updated_Master_Development_Prompt.md)
for the full product/phase specification driving this build.

**Status: Phase 7 — Compliance & Reporting complete.** Authentication,
multi-tenancy, RLS, equipment registry (Phase 1); sterilization cycles,
packs, QR, evidence, verification, release (Phase 2); OT/ward point-of-use
scanning, incidents, quarantine, realtime alerts (Phase 3); client-side
blur/exposure/glare checks (Phase 4); Document AI OCR (Phase 5);
Gemini-based indicator classification (Phase 6); and a hash-chain-verified
audit trail with a real WeasyPrint reporting service (Phase 7) are
functional. Phases 1-4 and 7 are fully verified against a local Supabase
stack; the actual Google Document AI and Gemini API calls are untested
since this environment has no real GCP/Gemini credentials — see
`docs/architecture/phase-5-ocr.md` and `phase-6-multimodal-ai.md` for
exactly what was and wasn't verified.

## Monorepo layout

```text
apps/mobile/    Flutter app (CSSD/OT staff)
apps/web/       React + TypeScript dashboard (admin/supervisor)
supabase/       Postgres schema, RLS policies, local dev config, Edge Functions (ocr-extract, gemini-analyze)
services/reporting/  Python/FastAPI/WeasyPrint PDF reporting service (Docker)
packages/contracts/  OpenAPI contract shared by both frontends
docs/           Architecture, database, API, workflow, validation notes
```

## Prerequisites

- Node.js 20+
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) (`brew install supabase/tap/supabase`)
- Docker Desktop (Supabase's local stack runs in containers)
- Flutter SDK (for `apps/mobile`) — not required to run the web app or database

## Local development

### 1. Start the backend

```bash
supabase start
```

This applies every migration in `supabase/migrations/` and seeds
`supabase/seed.sql` (two demo hospitals — see below). Note the `API_URL` and
`ANON_KEY` it prints; SteriCord's local ports are non-default (54421/54422/...)
because the default Supabase ports collided with another project on this
machine — see `supabase/config.toml`.

To re-apply migrations/seed from scratch:

```bash
supabase db reset
```

### 2. Run the web app

```bash
cd apps/web
cp .env.example .env.local   # fill in VITE_SUPABASE_ANON_KEY from `supabase status`
npm install
npm run dev
```

Sign in with a seeded user (password for all: `SteriCord!2026`):

| Email | Role | Organization |
|---|---|---|
| admin@hospital-a.test | HOSPITAL_ADMIN | Hospital A |
| supervisor@hospital-a.test | CSSD_SUPERVISOR | Hospital A |
| technician@hospital-a.test | CSSD_TECHNICIAN | Hospital A |
| nurse@hospital-a.test | OT_NURSE | Hospital A |
| admin@hospital-b.test | HOSPITAL_ADMIN | Hospital B |

Log in as both a Hospital A and a Hospital B user to see tenant isolation
directly — each only sees their own organization's equipment and staff.

To try the full CSSD workflow, sign in as `supervisor@hospital-a.test` (can
both operate and verify cycles): Cycles → Create Cycle → open it → Register
Pack → Start Cycle → Complete Cycle → upload an evidence file → Submit for
Verification → Verify Cycle (PASS) → Release the pack. A FAIL verification
instead cascades every pending pack in that cycle to QUARANTINED.

To try OT point-of-use safety, release a pack as above, then sign in as
`nurse@hospital-a.test` and go to Point of Use → enter the pack code →
record a PASS (pack marked `USED`) or a FAIL (pack quarantined, an incident
is created, and `admin@hospital-a.test`/`supervisor@hospital-a.test` get a
CRITICAL notification in the bell icon, delivered over Supabase Realtime).
Sign in as the supervisor to acknowledge/resolve the incident and release
the quarantine from the Incidents and Quarantine pages.

To see the image quality gate, try uploading a deliberately blurry or dark
photo as evidence on a cycle — it's rejected client-side with the specific
reason(s) before it ever reaches storage, and never appears in the evidence
list. A normal, well-lit photo is accepted and its blur/brightness/glare
scores are stored on the `evidence_files` row alongside it.

To try OCR, upload an AUTOCLAVE_RECEIPT evidence photo, then click "Extract
with OCR" on it. Without real Google Cloud credentials configured (the
default here), it comes back `NOT_CONFIGURED` with a clear message and an
empty confirmation form — fill in values by hand and confirm; the same
form works identically when OCR did run, just pre-filled. To exercise the
real Document AI call, set up
[`supabase/functions/.env`](./supabase/functions/.env.example) with a real
GCP project/processor/service-account key and restart `supabase start`.

To try AI indicator analysis, upload a BOWIE_DICK/CHEMICAL_INDICATOR/
BI_TRAY/OT_INDICATOR/WASHER_TEST evidence photo and click "AI analysis" →
"Analyze with AI". Without a `GEMINI_API_KEY`, it comes back
`NOT_CONFIGURED` the same way OCR does. With one configured, its suggestion
(and confidence band) shows as an advisory banner in the cycle Verify
dialog and the Point of Use verification form, pre-selecting — never
auto-submitting — the matching result; a LOW-confidence read is always
forced to `UNDETERMINED` server-side before it's ever stored, regardless
of what the model actually said.

To see the audit trail, go to Audit Trail and click "Verify Chain
Integrity" — it recomputes every event's hash from its own stored content
and reports "Chain intact" (or exactly which row was tampered with, if
any). To try reporting, run `docker compose up --build reporting` (needs
`services/reporting/.env` — copy from `.env.example` and fill in your
local `SUPABASE_ANON_KEY` from `supabase status`), then go to Reports and
download a real PDF for any equipment/cycle/incident, or click the
download icon next to any evidence file for its evidence sheet.

### 3. Run the mobile app

Requires the Flutter SDK, which is not installed in this environment. Once
available, see `apps/mobile/PLATFORM_SETUP.md` to generate the native
`android/`/`ios/` folders, then:

```bash
cd apps/mobile
cp .env.example .env   # fill in SUPABASE_ANON_KEY from `supabase status`
flutter pub get
flutter run
```

## Testing tenant isolation directly

```bash
PGPASSWORD=postgres psql -h 127.0.0.1 -p 54422 -U postgres -d postgres
```

```sql
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000a1001","role":"authenticated"}';
select * from public.equipment; -- only Hospital A's rows
rollback;
```

## Roadmap

Phases 1-7 (Foundation, CSSD Core, OT Point-of-Use Safety, Image Quality,
OCR / Document AI, Multimodal AI, Compliance & Reporting) are done. Next:
Phase 8 — Offline, Security & Pilot Hardening (offline capture queue, MFA,
security/device/performance testing, pilot deployment config) — the final
phase before hospital pilot readiness. See the master prompt for the full
phase list.
