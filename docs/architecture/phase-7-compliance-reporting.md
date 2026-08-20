# Phase 7 — Compliance & Reporting: architectural decisions

## The one service that actually needs to be a service

Phases 5 and 6 (OCR, Gemini) both turned into Supabase Edge Functions
rather than standalone services — Deno's `npm:` compatibility plus
`fetch`/`SubtleCrypto` covered everything they needed. Reporting doesn't
fit that pattern: WeasyPrint needs native Pango/Cairo/GDK-Pixbuf libraries
that no serverless or edge runtime provides. `services/reporting/` is a
real, separately-deployed Python/FastAPI container — not because section
52's "do not introduce unnecessary microservices" was ignored, but because
this is the one case where a genuinely different runtime is required, and
the master prompt's own tech stack (section 7) names "Python, WeasyPrint"
explicitly for this reason.

This also surfaced a real macOS-only development snag: Xcode's
hardened-runtime Python strips `DYLD_*` environment variables, so
WeasyPrint can locate its own installed native libraries via Homebrew on
the host but can't load them. That's a host quirk, not a WeasyPrint or
code problem — on Debian (the actual Dockerfile), the same libraries are a
plain `apt-get install` with no linking issues, which is also how this was
actually tested (see "Verified" below), not by fighting the host Python.

## Authorization: forward the user's JWT, add nothing

`SupabaseClient` in the reporting service takes the caller's own Supabase
access token and uses it for every PostgREST/Auth call — never a service
role key. This means the service has no independent authorization logic
to get wrong: every report is generated from exactly what RLS already lets
that user see, under the same policies the web and mobile apps are
governed by. A cross-tenant report request 404s not because the service
checked anything, but because Postgres returned zero rows for that user's
`organization_id`. Verified directly: Hospital B's admin requesting
Hospital A's equipment report got `404 {"detail":"equipment not found or
not accessible"}` — RLS did the work, not new Python code.

Every generated report also fans out a `REPORT_EXPORTED` audit event
(that enum value has existed since Phase 1's `audit_event_type`, unused
until now), logged via the same forwarded token so `actor_user_id`
resolves to the real requester rather than a service identity.

## Two real bugs this phase caught (and why they matter for compliance specifically)

1. **`log_audit_event()`'s hash was never actually re-derivable.** The
   original Phase 1 implementation hashed `clock_timestamp()` (read inside
   the function) while the row's own `occurred_at` column got a
   *separate* `now()` from the table's column default — two independent
   clock reads, microseconds apart. The exact string baked into
   `event_hash` was never persisted anywhere, so nothing could ever
   recompute it from the stored row alone; only hash-to-hash chain
   *linkage* was checkable, not that a row's hash still matched its own
   content. Fixed by capturing one timestamp and using it for both the
   inserted row and the hash input. This is exactly the kind of gap that
   only matters once you actually try to build the "verify this trail
   wasn't tampered with" feature Phase 7 requires — it had been silently
   sitting there since Phase 1.
2. **A column-name collision in `verify_audit_chain()`'s `RETURNS TABLE`
   parameters** (`occurred_at`, `event_type` — identical to
   `audit_events`' own column names) made the query inside the function
   ambiguous and made the function fail on every call. Fixed by prefixing
   the OUT parameters (`out_event_id`, etc.).

## Verified

- **Hash-chain integrity, both directions, with real tampering**: ran
  normal activity through the app, called `verify_audit_chain()` — zero
  issues (chain intact). Then, as a superuser bypassing the application
  entirely (the only way to tamper, since there is no `UPDATE` policy on
  `audit_events`), directly modified one row's `new_state` and called
  `verify_audit_chain()` again — it correctly flagged exactly that row
  with "event_hash does not match a recomputation from this row's own
  stored content," without false-flagging any other row. Also confirmed
  tenant isolation on the function itself (Hospital B can't verify
  Hospital A's chain).
- **All four report types generated as real PDFs** by building and
  running the actual Docker container (not the host Python) and hitting
  each endpoint with a real user JWT via curl: equipment, cycle, incident,
  and evidence-sheet reports all returned valid `PDF document, version
  1.7` files with correct data, correct branding, and correct null-safe
  rendering (an evidence row with no quality scores or OCR/AI data still
  renders cleanly, sections just omitted).
- **The full web flow** with a headless browser: Audit Trail page loads
  events, filters by entity type, and runs "Verify Chain Integrity"
  showing "Chain intact"; Reports page lists real equipment/cycles/
  incidents in each picker and a real PDF download completes end-to-end
  (confirmed via the actual network response and downloaded filename)
  through `services/reporting` running in Docker.
- **Retention timestamps**: confirmed `evidence_files.retention_expires_at`
  and `audit_events.retention_expires_at` are set to exactly 7 years from
  capture/occurrence on insert, matching section 23's stated maximum.
  Nothing reads or acts on these yet beyond storing them — actual
  lifecycle-driven archival/deletion is Phase 8 territory (a scheduled
  job), and deleting anything early is explicitly out of scope here.
