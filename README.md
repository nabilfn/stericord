# SteriCord

Hospital sterilization traceability and assurance platform. See
[SteriCord_Updated_Master_Development_Prompt.md](./SteriCord_Updated_Master_Development_Prompt.md)
for the full product/phase specification driving this build.

**Status: Phase 2 — CSSD Core complete.** Authentication, multi-tenancy, RLS,
equipment registry (Phase 1), plus sterilization cycles, instrument sets/
packs, QR generation, evidence capture, manual verification, and pack
release (Phase 2) are functional and verified against a local Supabase stack
(see `docs/architecture/phase-1-foundation.md` and `phase-2-cssd-core.md`).

## Monorepo layout

```text
apps/mobile/    Flutter app (CSSD/OT staff)
apps/web/       React + TypeScript dashboard (admin/supervisor)
supabase/       Postgres schema, RLS policies, local dev config
services/       Backend services added in later phases (ai, ocr, reporting, notifications)
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

Phases 1 (Foundation) and 2 (CSSD Core) are done. Next: Phase 3 — OT
Point-of-Use Safety (QR scanning, pack eligibility checks, indicator
capture, PASS/FAIL workflow, incidents, quarantine, alerts). See the master
prompt for the full phase list — AI integration (OpenCV/OCR/Gemini) is
mandatory but deliberately deferred until Phases 4-6, after CSSD and OT
workflows are functional.
