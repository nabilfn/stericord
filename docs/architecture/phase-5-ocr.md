# Phase 5 — OCR / Document AI: architectural decisions

## No credentials in this environment — built to the boundary, verified up to it

This environment has no real Google Cloud project, Document AI processor,
or service account. Per the master prompt's own rule (section 59: ask when
"an external account must be configured"), that was surfaced rather than
faked. What follows was built for real and tested as far as that boundary
allows:

- **Verified for real**: JWT-scoped authorization, RLS-scoped evidence
  lookup, the service-role storage/DB path, the `NOT_CONFIGURED` graceful
  path, `confirm_ocr_extraction()`'s role/org checks, tenant isolation on
  `ocr_extractions`, and the full web UI flow (upload → extract → manual
  entry → confirm) — all exercised against the running local stack with
  curl and a headless browser.
- **Not verified**: the actual HTTP call to Google's Document AI REST API
  and the OAuth2 service-account token exchange, since there's nothing real
  to call. The code implementing them follows Google's documented
  service-account JWT-bearer flow exactly; it just hasn't executed against
  a live endpoint. Wire up `supabase/functions/.env` (see
  `.env.example` there) with real credentials to exercise it.

## Where OCR runs: a Supabase Edge Function, not the client

A Document AI service-account private key must never reach a browser or a
phone. `supabase/functions/ocr-extract/` is the only place that key is
ever loaded, via an edge function secret (`GOOGLE_SERVICE_ACCOUNT_KEY_JSON`,
`supabase/functions/.env.example`) -- never the app's own `.env`. Both
clients call it through `supabase.functions.invoke()`, which forwards the
caller's session JWT; the function re-validates that JWT and uses it to
read `evidence_files` under normal RLS before doing anything privileged.

## REST calls with hand-rolled auth, not the official Node client

`google_auth.ts` implements the OAuth2 service-account JWT-bearer flow
(sign a JWT with the service account's private key via `SubtleCrypto`,
exchange it at `oauth2.googleapis.com/token`, call the Document AI REST
endpoint with the resulting bearer token) instead of importing
`@google-cloud/documentai` via `npm:`. That client's default transport is
gRPC, which is a materially less predictable thing to get working inside a
Deno edge sandbox than a couple of `fetch()` calls -- and the whole
JWT-bearer flow only needs Web-standard APIs (`fetch`, `crypto.subtle`),
so there's no reason to take on that risk.

## Regex field extraction, not a custom-trained entity extractor

There's no Document AI Custom Document Extractor here -- that needs a
labelled training set built in Document AI Workbench, well beyond this
phase. `field_extraction.ts` instead runs label-pattern regexes (`"Cycle
No:"`, `"Temp:"`, etc.) over the generic OCR processor's plain-text output
to guess at `cycle_number`, `temperature`, `pressure`, `hold_time_seconds`,
`date`, `time`, `machine_identifier`, and `result`. Thermal receipt layouts
vary by autoclave manufacturer, so this **will** miss fields on formats it
hasn't seen. That is exactly why section 34's "do not make OCR output
authoritative without review" rule matters here, not a caveat around it.

## Two-column authority split

`ocr_extractions.extracted_fields` is what the pipeline guessed.
`human_confirmed_fields` is a separate column, written only by
`confirm_ocr_extraction()` (never a direct client UPDATE), and it's the
only one anything downstream may treat as authoritative. Nothing in the
schema currently reads `extracted_fields` automatically into cycle data --
a human always looks at the (possibly pre-filled, possibly empty) form and
explicitly confirms first. This mirrors the `ai_suggested_result` /
`human_result` split already established on `verifications` in Phase 2.

## Graceful degradation when OCR isn't configured

Missing credentials produce an `ocr_extractions` row with
`status = 'NOT_CONFIGURED'` and a clear `error_message`, not a 500. The
confirmation form works identically either way -- pre-filled from
`extracted_fields` when OCR ran, or blank for a supervisor to fill by hand
when it didn't. A hospital that hasn't set up Document AI yet still gets a
working structured-data-entry workflow for autoclave receipts; OCR is an
accelerant on top of that, not a hard dependency.

## A bug this testing caught: service_role had no table grants

Every write before this phase went through a `security definer` Postgres
function owned by `postgres` (which has full privileges as the table
owner regardless of grants). `ocr-extract` is the first code path to
`INSERT` directly via a service-role PostgREST client, and it failed with
"permission denied for table ocr_extractions" -- the Phase 1 grants
migration only ever granted `authenticated`, never `service_role`, and
`BYPASSRLS` only skips row security, it doesn't substitute for the
table-level `GRANT` Postgres checks first. Fixed retroactively in
`20260821000003_service_role_grants.sql` for every table, not just this
one, since the same gap would have hit any future service-role code path.
