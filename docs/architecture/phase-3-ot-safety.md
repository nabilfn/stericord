# Phase 3 — OT Point-of-Use Safety: architectural decisions

## One function is the entire safety-critical path

`public.record_point_of_use_verification()` is the sole entry point for an
OT/ward scan-and-verify event. On `FAIL` it does not just flip a status
flag — in the same transaction it:

1. inserts the `point_of_use_records` row;
2. inserts a matching `verifications` row (keeping the human decision in the
   same audit-friendly table cycles/packs already use);
3. moves the pack to `QUARANTINED`;
4. creates an `incidents` row (`status = 'ALERTED'` immediately — creating
   the notification *is* the alert, so there's no separate "now go alert
   someone" step to forget);
5. creates a `quarantines` row linked back to that incident
   (`source_incident_id`);
6. fans out one `notifications` row to every active `HOSPITAL_ADMIN` /
   `CSSD_SUPERVISOR` in the org via `notify_roles()`;
7. writes `INCIDENT_CREATED`, `QUARANTINE_STARTED`, and
   `OT_VERIFICATION_COMPLETED` audit events.

This directly implements Milestone 2 (master prompt section 54): "FAIL
must: Create Incident, Alert CSSD, Quarantine Pack, Create Audit Event" —
as one atomic database transaction, not four separate client-side calls
that could partially fail or be skipped.

`UNDETERMINED` intentionally changes nothing about the pack's state. Per
section 4, "`UNDETERMINED` must always require manual review" — the record
is kept for follow-up, but nothing is auto-decided either way.

## Eligibility is checked twice, by design

`check_pack_eligibility()` is a separate, read-only function so the client
can show "not eligible" before the nurse spends time on indicator capture.
But `record_point_of_use_verification()` re-runs the same check itself
before writing anything — the client-side check is a UX convenience, not
the enforcement point. A pack that expires or gets used by someone else in
the seconds between the two calls is still correctly rejected.

## Notifications: fan-out at write time, not fan-out at read time

Each notification is one row per recipient (`recipient_user_id`, not a
shared row with a role filter), created by `notify_roles()` at the moment
of the triggering event. This was chosen over a shared "org + target role"
row because per-user read/unread state (`is_read`, `read_at`) becomes a
plain boolean on each recipient's own row instead of needing a separate
read-receipts table. The tradeoff is some duplication (N rows for N
recipients) — an acceptable one at hospital-department alert volumes.

Realtime is real, not just modeled: `public.notifications` is added to the
`supabase_realtime` publication, and both the web `NotificationBell` and
the mobile `NotificationsPage` subscribe to `postgres_changes` filtered to
`recipient_user_id = <self>`. This is the literal implementation of the
master prompt's own example in section 8: "Realtime notification created →
React supervisor dashboard receives alert."

## Incidents: the full state vocabulary, no invented transition graph

The master prompt (section 26) specifies nine `incident_status` values but
does not define exactly which transitions are legal between all of them.
Rather than invent a strict graph the spec doesn't support,
`advance_incident_status()` only enforces what's unambiguous: `RESOLVED`
and `CLOSED` are terminal, and only those two states are reachable via the
dedicated `resolve_incident()` function (which also stamps
`resolved_by`/`resolved_at`/`resolution_notes`). Every other transition
(`ACKNOWLEDGED`, `REPLACEMENT_DISPATCHED`, etc.) is available to a
supervisor without a hard-coded graph, honoring "do not reduce incident
handling to a single boolean" without guessing at rules that weren't given.

## Releasing a quarantine does not un-quarantine the pack

`release_quarantine()` only updates the `quarantines` row (documenting that
an investigation concluded). It deliberately does **not** move the
underlying `instrument_packs.status` back to `RELEASED`. A pack that failed
an OT indicator check is treated as permanently out of service for Phase 3
— the safe clinical default, matching section 39's caution around
equipment lockout ("unlock requires... reason... audit record") applied to
the pack side: nothing silently re-enters circulation.

## Verified end-to-end (Phase 3)

- Full SQL path: released pack → OT nurse PASS → pack `USED`; released pack
  → OT nurse FAIL → pack `QUARANTINED`, incident `ALERTED`/`CRITICAL`,
  quarantine `ACTIVE`, two notifications fanned out (admin + supervisor,
  not the technician). Re-verification of an already-`USED` pack is
  rejected by `check_pack_eligibility()`.
- Supervisor path: acknowledge → resolve+close an incident, release its
  linked quarantine, mark a notification read — all via SQL and via the
  actual web UI.
- Full web UI run with a headless browser: OT nurse PASS and FAIL flows,
  supervisor incident acknowledge/resolve, quarantine release, and the
  realtime-delivered notification bell — zero console errors.
- One real bug caught by this testing and fixed: `resolve_incident()`'s
  `CASE WHEN ... THEN 'CLOSED' ELSE 'RESOLVED' END` needed an explicit
  `::public.incident_status` cast — Postgres won't infer an enum type from
  two untyped string literals in a CASE expression assigned to an enum
  column.
