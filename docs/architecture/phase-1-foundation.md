# Phase 1 — Foundation: architectural decisions

## Multi-tenancy and RLS

Every tenant-scoped table carries `organization_id`. Isolation is enforced at
the database layer via Postgres Row-Level Security, not only in application
code — this is intentional: a bug in the web or mobile client cannot leak
Hospital A's data to Hospital B, because Postgres itself refuses the row.

Three `security definer` helper functions back every policy
(`supabase/migrations/20260819000004_rls_helpers.sql`):

- `current_organization_id()` — the calling user's home organization.
- `user_has_role(org, roles[])` — whether the caller holds one of the given
  roles in that organization.
- `is_system_admin()` — whether the caller can cross tenant boundaries.

They run as `security definer` + `stable` so policies can call them without
recursively re-triggering RLS on `profiles`/`user_roles`.

Recent Supabase versions do **not** auto-expose newly created tables to the
`anon`/`authenticated` PostgREST roles. RLS policies alone are not enough —
table-level `GRANT`s are also required (`20260819000008_grants.sql`), plus
`ALTER DEFAULT PRIVILEGES` so future migrations don't need to repeat this.

## Audit trail

`audit_events` is append-only by construction: there is no `UPDATE` or
`DELETE` RLS policy on the table, and the only way to insert a row is through
`public.log_audit_event(...)`, a `security definer` function that computes a
SHA-256 hash chain (`event_hash` / `previous_event_hash`) per organization.
This satisfies the master prompt's requirement that "critical audit events
cannot be modified through normal application access" — verified directly
against the running local database (see below).

## Equipment status history

`equipment.operating_status` changes are mirrored into
`equipment_status_events` by an `AFTER INSERT/UPDATE` trigger
(`record_equipment_status_change`), not by application code — so history
can't be forgotten by a client that skips a step. The table itself has no
update/delete policy, matching the "do not erase status history" rule.

## Local dev ports

The default Supabase CLI ports (54321/54322/...) collided with another
project already running on this machine. SteriCord's local stack is
reassigned to the 5442x block in `supabase/config.toml` — see that file for
the full mapping. This only affects local development; it has no bearing on
a hosted Supabase project's ports.

## Verified invariants (Phase 1)

Run directly against the local database after `supabase start`:

- Hospital A's admin sees only Hospital A's `organizations`, `equipment`,
  and `profiles` rows; Hospital B's admin sees only Hospital B's.
- Hospital A's admin cannot `INSERT` equipment under Hospital B's
  `organization_id` (RLS `WITH CHECK` rejects it).
- `audit_events` rows cannot be updated even by an authenticated org member
  (zero rows match — no policy grants it).
- The same invariants hold end-to-end through the web app (Playwright-driven
  browser test: login → dashboard → equipment list → equipment detail, for
  both a Hospital A and a Hospital B seed user).
