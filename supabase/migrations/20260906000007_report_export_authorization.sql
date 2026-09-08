-- SteriCord QA remediation D-05 (FF-19): a valid OT_NURSE session could
-- generate/download an equipment compliance PDF (HTTP 200) and the export
-- still logged a REPORT_EXPORTED audit row as if it were legitimate.
--
-- The reporting service was built on "RLS is the entire authorization
-- story" (see docs/architecture/phase-7-compliance-reporting.md), which is
-- correct for "can this user see this row in the app" -- SELECT policies on
-- equipment/cycles/incidents/evidence_files are deliberately org-wide, any
-- role can see their own hospital's data in the UI. "May this user export
-- a formal compliance PDF of it" is a narrower permission that doesn't map
-- to any table-level SELECT policy, so it was never actually checked
-- anywhere -- not in Postgres, not in the Python service.
--
-- Fixing this as a database RPC (not as new authorization logic inside the
-- FastAPI service) keeps every authorization decision in the same place:
-- the reporting service still never re-implements a role check itself, it
-- just calls one more thing Postgres already knows how to answer.

create or replace function public.can_export_compliance_reports()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    public.user_has_role(
      public.current_organization_id(),
      array['HOSPITAL_ADMIN', 'CSSD_SUPERVISOR', 'AUDITOR', 'QUALITY_MANAGER']::public.user_role[]
    )
    or public.is_system_admin();
$$;

comment on function public.can_export_compliance_reports is 'Canonical role gate for compliance PDF export (section 41''s reporting service): HOSPITAL_ADMIN, CSSD_SUPERVISOR, AUDITOR, QUALITY_MANAGER, or SYSTEM_ADMIN. Deliberately excludes CSSD_TECHNICIAN, OT_NURSE, BIOMEDICAL_ENGINEER, and INFECTION_CONTROL -- those roles operate/verify/scan but do not export formal compliance records. Already respects the is_active_user() fix via current_organization_id()/user_has_role()/is_system_admin(), so a deactivated account loses report-export ability the same way it loses everything else.';
