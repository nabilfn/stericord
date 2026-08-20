# Phase 8 — Offline, Security & Pilot Hardening: architectural decisions

## What's real vs. what's written-but-unverified this phase

Every previous phase in this build had a hard credential or tooling
boundary (no GCP/Gemini keys, no Flutter SDK) and drew a clear line at it:
verify everything up to the boundary for real, write the rest carefully,
and say so. Phase 8 has the same shape. The server-side and web-app pieces
(MFA, rate limiting, backups, the AI validation view, the security test
suite, offline sync's idempotency) all ran against the real local stack.
The mobile offline queue itself (`apps/mobile/lib/core/offline/`) is
written against the same conventions as every other Flutter file in this
repo, but this environment has no Flutter SDK to compile or run it --
see the pilot checklist for what has to happen on a real device before
that code is trusted with a real OT shift.

## MFA: Supabase's own TOTP, not a third-party add-on

`auth.mfa.totp` was enabled in the local stack's `config.toml`
(`enroll_enabled`/`verify_enabled`, both false by default) rather than
building a custom TOTP flow -- GoTrue already implements RFC 6238 TOTP
enrollment/challenge/verify, so the web app's `MfaSettings` and
`MfaChallengePage` are thin wrappers around `supabase.auth.mfa.*`, and
`ProtectedRoute` checks `getAuthenticatorAssuranceLevel()` to gate entry
behind a challenge when a verified factor exists but the current session
hasn't presented one yet (`aal1` current, `aal2` next).

Enrollment is opt-in per account, not enforced by RLS or the app --
enforcing it would break every seeded demo credential used throughout
this session, and a real hospital rollout enforces it operationally
(HOSPITAL_ADMIN/CSSD_SUPERVISOR mandated, others optional) rather than by
the code refusing to let an unenrolled account exist at all. See the
pilot checklist for the actual pre-go-live enrollment expectation.

**Verified end-to-end with a real, independently-implemented TOTP
generator** (RFC 6238/4226, hand-rolled against Node's `crypto` and
checked against the RFC's own published test vectors before trusting it --
see the commit for the exact vectors): enrolled a factor via the real QR
secret, verified with a real generated code, confirmed the next login is
gated behind a challenge, confirmed a wrong code is rejected and the
correct one is accepted, confirmed disabling removes the gate. Zero
console errors other than the expected 422 from the deliberate
wrong-code test.

## Rate limiting: the one place a single bad request is expensive

Every other endpoint in this system is a bounded PostgREST/RPC call;
report generation is the one place a single request runs a full WeasyPrint
render. `services/reporting/app/main.py` adds a per-user (JWT `sub`,
unverified since PostgREST re-verifies the token on every actual data
call regardless) sliding-window limiter -- 30 requests/minute, in-memory
and per-process, which is correct for this single-instance service and
explicitly documented as needing a shared store (Redis) if ever scaled
horizontally. **Verified**: 30 real requests succeeded, the 31st and 32nd
returned 429, and a second user's requests were unaffected (bucket keyed
per-subject, confirmed independently).

## Backups: tested as an actual restore, not just a `pg_dump` that ran

`infrastructure/deployment/backup-db.sh` / `restore-db.sh` use `pg_dump
-Fc` (custom format, required for `pg_restore --list` verification and
parallel restore) and `pg_restore --clean --if-exists`. **Verified with a
real round-trip**: backed up the local stack, restored into a disposable
`postgres:17` container (not the same Supabase image, deliberately, to
prove the dump doesn't depend on anything Supabase-specific for the
actual application data), and confirmed all 19 `public` schema tables and
exact seeded row counts (3 equipment, 2 organizations) came back intact.
The only errors were `supabase_vault`-related, since that extension only
exists in Supabase's own Postgres build -- documented directly in
`restore-db.sh` rather than treated as a hidden gotcha for whoever runs it
next.

## AI validation: no new table, because the data already existed

Phase 6 already copies `ai_suggested_result`/`ai_confidence` onto every
`verifications` row alongside the authoritative `human_result` -- built
that way specifically so this kind of accuracy tracking wouldn't need a
schema change later. `ai_validation_summary` is a `security_invoker = true`
view (Postgres 17 here; the flag is required, not stylistic --
without it the view runs as its owning migration role, which bypasses
RLS, and would leak every organization's AI accuracy numbers to any
querying user) that aggregates agreement rate, false-PASS count (the
safety-critical direction -- AI said PASS, a human caught it as FAIL),
false-FAIL count, and abstention count, grouped by `verification_type`.

It's deliberately *not* grouped by indicator type: `verifications` doesn't
store which `ai_analyses` row informed it, only a copy of its result and
confidence, and a join back to `ai_analyses` on those two values alone
would silently misattribute rows whenever two analyses on the same entity
happen to share a result and confidence. A coarser-grained correct number
beats a finer-grained wrong one reported as compliance data.

**Verified**: inserted synthetic AI-assisted verifications directly,
confirmed the view's aggregates match hand-computed values exactly
(5 rows -> 2 agreed, 1 false-pass, 1 false-fail, 1 abstained, 50% agreement
excluding the abstention), confirmed Hospital B genuinely sees zero rows
of Hospital A's data through the view (not just via the app -- via a raw
`set local request.jwt.claims` query), and confirmed the same numbers
render correctly in the Audit Trail page's new "AI validation" card via a
real browser session.

## Offline sync: idempotency is the actual hard problem, not encryption

Section 42's pipeline (Capture -> Encrypted Local Storage -> Local
Operation ID -> Sync Queue -> ... -> Server Acknowledgement -> Local
State Reconciled) has an unstated requirement underneath it: a client
that doesn't know whether its last request actually reached the server
before the connection dropped must be able to retry it without creating
a duplicate. That's what actually needed building carefully, not the
encryption (AES-256-GCM via `flutter_secure_storage` + `encrypt`, a
standard pattern).

`client_operation_log` (new table, Phase 8) is the idempotency ledger:
`record_point_of_use_verification` now accepts an optional
`p_client_operation_id`, checks the ledger first, and returns the
original result on a repeat instead of re-inserting -- deliberately
checked *before* the eligibility check, since eligibility legitimately
changes as a side effect of the first successful call (a pack goes from
`RELEASED` to `USED`), and re-checking it on a replay would make a
successful retry look like a failure. Scoped to OT point-of-use only, not
every mobile write path: that's the one flow field staff actually run
with unreliable connectivity (an OT with no signal), while CSSD's cycle
functions run in a fixed room assumed to have wifi.

**Verified against the real local stack, not just read as code**: called
the RPC twice with the same `client_operation_id` inside one session --
both calls returned the identical `point_of_use_records.id`, and exactly
one row existed afterward. A second, different operation id was confirmed
to still create a genuinely new record (the idempotency check isn't
accidentally swallowing all calls).

The Dart side (`OfflineQueueRepository`, `SyncService`,
`PointOfUseRepository.recordVerification`) generates the operation id
*before* attempting a direct network call, not only when falling back to
the queue -- a direct call can time out after the server already
committed it, so the fallback's queued retry has to carry the same id the
original attempt used, or the server has nothing to recognize it by. This
was caught and fixed during review, not shipped with the gap: the first
draft generated a fresh id only at enqueue time, which would have
duplicated exactly the kind of request this feature exists to protect
against. Unverified end-to-end (no Flutter SDK), but the server-side half
it depends on is real.

## Security testing: automated, not a one-time manual pass

`infrastructure/deployment/security-checks.sh` asserts eight specific
negatives against the live local stack and is safely re-runnable (each
run uses a fresh timestamped test-cycle number and cleans up after
itself): cross-tenant reads blocked on `equipment` and `audit_events`,
cross-tenant `verify_audit_chain()` blocked, a CSSD technician's direct
`UPDATE` on equipment status silently affects zero rows (no matching RLS
policy for that role), `audit_events` cannot be deleted, a technician
cannot call `verify_cycle` (supervisor/admin only), the evidence storage
bucket rejects an anonymous request, and PostgREST itself rejects a
request with no API key at all. All eight passed, twice in a row.

## Performance: a local smoke test and an honest baseline, not a capacity claim

`ab -n 200 -c 10` against `GET /rest/v1/equipment` on the local stack:
1122.69 req/s mean, 0 failed. Ten sequential real PDF generations through
the rate-limited reporting service (full round trip: auth check, three
PostgREST queries, a real WeasyPrint render) averaged ~169ms each. Both
numbers are a single-machine, local-stack baseline worth regression-
testing against later, not a claim about pilot-scale concurrent load --
see the pilot checklist.

## What section 41 asks for that this phase deliberately did not build

**Monitoring** and **device testing** are the two checklist items with no
real artifact here, for the same reason OCR/Gemini stayed at
`NOT_CONFIGURED` in earlier phases: monitoring needs a real APM
provider's credentials to be more than a config file nobody can verify
routes anywhere, and device testing needs a physical device this sandbox
doesn't have. Building either as an unverifiable stub would be worse than
naming the gap plainly -- both are called out explicitly in the pilot
checklist as pre-go-live requirements, not silently skipped.
