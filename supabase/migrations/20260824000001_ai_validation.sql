-- SteriCord Phase 8: AI validation (master prompt section 41's "AI validation"
-- checklist item, and section 38's "AI Safety" principle that AI may only
-- assist -- so its assistance needs to be measurably trustworthy over time,
-- not just gated per-call by confidence bands).
--
-- No new fact table is needed: every AI-assisted verification already pairs
-- ai_suggested_result with the authoritative human_result in
-- verifications (see the Phase 6 migration's "collect labelled data from the
-- start" comment) -- this migration only adds a read-only summary over data
-- that already exists.
--
-- Deliberately grouped by verification_type only, not indicator_type:
-- verifications doesn't store which ai_analyses row informed it (only a copy
-- of its suggested_result/confidence), so there is no reliable key back to
-- ai_analyses.indicator_type. Joining on suggested_result+confidence match
-- would silently misattribute rows whenever two analyses on the same entity
-- happen to share a result and confidence -- a wrong number reported as
-- compliance-grade AI safety data is worse than a coarser-grained right one.
--
-- security_invoker = true is required, not optional: without it, this view
-- would run with its owning role's privileges (the migration role, which
-- bypasses RLS), silently leaking every organization's AI accuracy into any
-- caller's query instead of being scoped by current_organization_id() like
-- every other table in this schema.

create view public.ai_validation_summary
with (security_invoker = true)
as
select
  organization_id,
  verification_type,
  count(*) as total_ai_assisted,
  count(*) filter (where ai_suggested_result = human_result) as agreed,
  count(*) filter (where ai_suggested_result = 'PASS' and human_result = 'FAIL') as false_pass_count,
  count(*) filter (where ai_suggested_result = 'FAIL' and human_result = 'PASS') as false_fail_count,
  count(*) filter (where ai_suggested_result = 'UNDETERMINED') as abstained_count,
  round(
    count(*) filter (where ai_suggested_result = human_result)::numeric
      / nullif(count(*) filter (where ai_suggested_result <> 'UNDETERMINED'), 0),
    4
  ) as agreement_rate_excl_abstentions,
  min(verified_at) as first_verified_at,
  max(verified_at) as last_verified_at
from public.verifications
where ai_suggested_result is not null
group by organization_id, verification_type;

comment on view public.ai_validation_summary is 'Read-only accuracy summary of AI-assisted verifications vs. the authoritative human_result, grouped by verification_type. Advisory only -- for AI safety oversight (section 38), never used to gate or auto-approve anything. false_pass_count (AI said PASS, human said FAIL) is the safety-critical direction to watch.';

grant select on public.ai_validation_summary to authenticated;
