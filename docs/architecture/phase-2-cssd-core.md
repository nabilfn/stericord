# Phase 2 — CSSD Core: architectural decisions

## State machine lives in Postgres functions, not client code

`cycle_status` and `pack_status` transitions do not have a general client
UPDATE policy at all — `sterilization_cycles` and `instrument_packs` only
grant INSERT (create) and SELECT directly. Every transition
(`start_cycle`, `complete_cycle`, `submit_cycle_for_verification`,
`verify_cycle`, `release_pack`, `quarantine_pack`) is a `security definer`
Postgres function in
`supabase/migrations/20260820000007_cssd_workflow_functions.sql` that:

1. re-checks org membership and role authorization itself (security definer
   bypasses RLS, so it must not skip authorization);
2. validates the source state explicitly (e.g. `release_pack` raises unless
   the pack is `PENDING_VERIFICATION`);
3. performs the transition and any required cascade;
4. writes an `audit_events` row via `log_audit_event`.

This was a deliberate choice over "any authorized role can UPDATE the status
column" (which is how Phase 1's `equipment.operating_status` works): cycles
and packs have a **cross-table** invariant — a pack can't be released unless
its parent cycle passed — that a single-table RLS policy can't express. A
client bug or a malicious request replaying a raw PATCH cannot skip a step,
because there is no direct write path to skip through.

## The critical invariant, enforced twice

Master prompt section 50 requires: "Released pack cannot come from a failed
cycle." `release_pack()` checks the parent cycle's `cycle_status = 'PASSED'`
before allowing the transition, in the same function, in the same
transaction as the pack update. This was verified directly against the
database:

- `release_pack()` on a pack still `PENDING_VERIFICATION` before the cycle's
  own verification → rejected.
- `verify_cycle(..., 'FAIL')` cascades every `PENDING_VERIFICATION` pack in
  that cycle to `QUARANTINED` — so `release_pack()` on any of them then fails
  for a second, independent reason (`Pack must be PENDING_VERIFICATION to
  release`), satisfying "quarantined pack cannot be used" without needing
  the full incidents/quarantines tables (those are Phase 3).
- Verified again end-to-end through the actual web UI with a headless
  browser, not just SQL.

## Evidence gate before verification

`submit_cycle_for_verification()` refuses to move a cycle from `COMPLETED`
to `PENDING_VERIFICATION` unless at least one `evidence_files` row exists
for it. This turns "capture evidence before verifying" from a UI convention
into a server-enforced rule.

## Storage: bucket-path convention instead of per-row policies

Evidence binaries live in the private `evidence` Supabase Storage bucket.
Object paths are always `{organization_id}/{entity_type}/{entity_id}/...`,
and a single pair of `storage.objects` RLS policies (Select/Insert) checks
`(storage.foldername(name))[1] = current_organization_id()`. This scales to
every future entity type (packs, and later OT point-of-use records in
Phase 3) without new storage policies — only the `evidence_files` metadata
table needs a new row.

`StorageProvider` (`apps/web/src/services/storageProvider.ts`) intentionally
implements only `uploadEvidence` / `generateSignedUrl` / `calculateHash` —
the operations Phase 2 uses. `archiveEvidence` / `deleteExpiredEvidence`
belong to the Phase 7 retention lifecycle and will be added to the interface
then, not stubbed out now.

## QR codes are opaque tokens, not row IDs

`instrument_packs.qr_code` defaults to a random 32-character hex string
(`replace(gen_random_uuid()::text, '-', '')`), independent of the row's own
`id`. Per master prompt section 20/47: QR codes must not encode sensitive
or structurally revealing data. A pack's QR can be reprinted with a fresh
token later (Phase 3+) without needing to change its primary key or any
foreign keys pointing to it.

## `cycle_type` is free text, not an enum

Unlike `equipment_type`, `cycle_type` (e.g. "Prevac 134°C 4min") is stored
as free text. The master prompt doesn't define a fixed vocabulary for cycle
types the way it does for equipment types, roles, or statuses, and hospitals
vary in how they name cycle programs — inventing a taxonomy here would be
guessing at a requirement that wasn't given.

## Verified end-to-end (Phase 2)

- Full happy path through raw SQL: create → register pack → start → complete
  → upload evidence → submit → verify PASS → release (with the early-release
  and wrong-role attempts both rejected).
- Full failure path: verify FAIL → pack cascades to QUARANTINED → release
  attempt rejected.
- Same happy path repeated through the actual web UI with a headless
  browser (cycle creation, pack registration, evidence upload, verification,
  release, QR code render) — zero console errors.
- Tenant isolation holds on every new table (cycles, packs, instrument sets,
  evidence, verifications) — checked both via direct SQL and through the
  running web app.
