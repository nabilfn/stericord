-- Fix: service_role never received table-level GRANTs.
--
-- The Phase 1 grants migration (20260819000008_grants.sql) only granted
-- privileges to `authenticated`, on the assumption that service_role -- used
-- by trusted server contexts (Edge Functions, admin scripts) -- effectively
-- bypasses RLS and therefore doesn't need explicit grants the way
-- `authenticated` does. That assumption was wrong: BYPASSRLS only skips row
-- security policies, it does not substitute for the table-level GRANT
-- Postgres checks first. Every write before this migration happened through
-- a security-definer function owned by `postgres` (which has full
-- privileges as the owner), so the gap never surfaced -- ocr-extract is the
-- first code path to INSERT directly via the service-role PostgREST client
-- instead of through such a function, and it failed with
-- "permission denied for table ocr_extractions" until this was added.

grant usage on schema public to service_role;

grant select, insert, update, delete on all tables in schema public to service_role;

alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;

alter default privileges in schema public
  grant execute on functions to service_role;
