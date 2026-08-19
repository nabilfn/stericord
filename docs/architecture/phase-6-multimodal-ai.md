# Phase 6 — Multimodal AI (Gemini): architectural decisions

## Same posture as Phase 5: no real credentials, built and verified to the boundary

This environment has no `GEMINI_API_KEY`. Applying the same precedent the
user set for Phase 5 (OCR) rather than re-asking an identical question:
build the full pipeline for real, verify everything short of the actual
external API call, and say plainly what wasn't exercised.

- **Verified for real**: JWT-scoped authorization, RLS-scoped evidence
  lookup, the `NOT_CONFIGURED` graceful path (curl and headless browser),
  server-side confidence forcing (code-reviewed and the arithmetic is
  simple enough to be confident in without a live model response to feed
  it), tenant isolation on `ai_analyses`, the `verify_cycle()`/
  `record_point_of_use_verification()` linkage (tested with a manually
  inserted `COMPLETED` row standing in for a real Gemini response), and
  the full web UI flow end-to-end with a headless browser (upload
  indicator photo → suggestion banner in the verify dialog → pre-selected
  radio → human confirms → linkage persisted in `verifications`).
- **Not verified**: the actual HTTP call to Gemini's Generative Language
  API. `gemini_client.ts` follows Google's documented REST + API-key usage
  exactly; it just hasn't executed against a live endpoint. Set
  `GEMINI_API_KEY` in `supabase/functions/.env` to exercise it for real.

## Confidence routing is enforced in the edge function, not just the UI

Section 36 says "never force uncertain AI into PASS or FAIL." That's
implemented as code, not a display convention: `gemini-analyze/index.ts`
computes a confidence band (HIGH ≥ 0.85, MEDIUM ≥ 0.6, LOW below) and, if
the band is LOW, **rewrites** `suggested_result` to `UNDETERMINED` before
it's ever written to `ai_analyses` — regardless of what Gemini's raw JSON
said. A client bug, a modified request, or a compromised frontend cannot
cause a low-confidence read to present as a confident PASS or FAIL,
because the confident-looking value never reaches the database in the
first place.

## Two authoritative-outcome links, same pattern as Phase 5

`verify_cycle()` and `record_point_of_use_verification()` (Phase 2/3) each
gained an optional `p_ai_analysis_id` parameter. When present, the
function looks up that `ai_analyses` row's `suggested_result`/`confidence`
and copies them into the new `verifications` row's existing
`ai_suggested_result`/`ai_confidence` columns (present since Phase 2, unused
until now) — so the AI's suggestion and the human's actual decision live
side by side on the same row, satisfying section 37's "collect labelled
data from the start" without a new table. Nothing about this is
authoritative on its own: `human_result` remains the only column anything
downstream (pack release, quarantine cascade) ever reads.

## A bug this testing caught: `CREATE OR REPLACE FUNCTION` doesn't replace on a signature change

Adding `p_ai_analysis_id` to `verify_cycle()` via `CREATE OR REPLACE
FUNCTION` did not replace the Phase 2 three-argument version — Postgres
identifies a function by name **and** argument types, so this silently
created a second, overloaded `verify_cycle`. Calling it the old way (three
arguments, exactly how every existing call site in both apps calls it)
then failed with `function ... is not unique`, because Postgres couldn't
tell whether to resolve to the old three-arg function or the new four-arg
one with its default applied. This would have broken every cycle and
point-of-use verification in the running app the moment this migration
shipped. Fixed with an explicit `DROP FUNCTION IF EXISTS` (exact old
signature) before each `CREATE OR REPLACE`, and reverified both the
old-style three-argument call and the new four-argument call succeed side
by side after the fix.

## Why indicator prompts explicitly disclaim clinical authority

`gemini_client.ts`'s prompt tells the model directly that it is "NOT
making a clinical or patient-safety decision" and to describe only what is
visible, never to state or imply sterility is confirmed. This is
defense-in-depth alongside the code-level confidence forcing and the
human-confirmation requirement — section 38 draws a hard line ("AI may
assist/classify/recommend/flag; it may never autonomously declare a
result"), and that line is enforced at three independent layers: the
prompt (what the model is told to do), the edge function (confidence
forcing), and the schema (`human_result`, never `ai_suggested_result`, is
what any workflow function actually acts on).
