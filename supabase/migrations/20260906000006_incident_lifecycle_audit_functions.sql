-- SteriCord QA remediation D-03 (FF-14), continued: fix
-- acknowledge_incident(), advance_incident_status(), and resolve_incident()
-- to each log the audit event that actually names what happened, and to
-- log it exactly once per successful transition. Kept in its own migration
-- after the enum additions above so the new enum values are already
-- committed and usable.
--
-- Every raise exception path below runs (and rolls back) before any
-- log_audit_event call, so a rejected transition -- terminal-state
-- regression, unauthorized nurse advancement, an unresolved incident being
-- closed -- never reaches an audit call and never produces a misleading
-- success record. Signatures are unchanged from the originals, so CREATE
-- OR REPLACE is safe here.

create or replace function public.acknowledge_incident(p_incident_id uuid)
returns public.incidents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_incident public.incidents;
  v_previous_status public.incident_status;
begin
  select * into v_incident from public.incidents where id = p_incident_id for update;
  if v_incident is null then
    raise exception 'Incident % not found', p_incident_id;
  end if;
  if v_incident.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_incident.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to acknowledge an incident';
  end if;
  if v_incident.status not in ('DETECTED', 'ALERTED') then
    raise exception 'Incident must be DETECTED or ALERTED to acknowledge (current status: %)', v_incident.status;
  end if;

  v_previous_status := v_incident.status;

  update public.incidents
  set status = 'ACKNOWLEDGED', acknowledged_by = auth.uid(), acknowledged_at = now()
  where id = p_incident_id
  returning * into v_incident;

  perform public.log_audit_event(
    v_incident.organization_id, 'INCIDENT_ACKNOWLEDGED', 'incident', p_incident_id,
    jsonb_build_object('status', v_previous_status),
    jsonb_build_object('status', v_incident.status)
  );

  return v_incident;
end;
$$;

-- Maps a target incident_status to the audit event type that actually
-- names it. Not exposed outside this file; advance_incident_status() is
-- the only caller.
create or replace function public._incident_status_audit_event(p_status public.incident_status)
returns public.audit_event_type
language sql
immutable
as $$
  select case p_status
    when 'REPLACEMENT_DISPATCHED' then 'INCIDENT_REPLACEMENT_DISPATCHED'::public.audit_event_type
    when 'REPLACEMENT_RECEIVED' then 'INCIDENT_REPLACEMENT_RECEIVED'::public.audit_event_type
    when 'QUARANTINE_IN_PROGRESS' then 'INCIDENT_QUARANTINE_IN_PROGRESS'::public.audit_event_type
    when 'NCR_OPEN' then 'INCIDENT_NCR_OPEN'::public.audit_event_type
    else null
  end;
$$;

create or replace function public.advance_incident_status(p_incident_id uuid, p_new_status public.incident_status)
returns public.incidents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_incident public.incidents;
  v_previous_status public.incident_status;
  v_event_type public.audit_event_type;
begin
  select * into v_incident from public.incidents where id = p_incident_id for update;
  if v_incident is null then
    raise exception 'Incident % not found', p_incident_id;
  end if;
  if v_incident.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_incident.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to update this incident';
  end if;
  if v_incident.status in ('RESOLVED', 'CLOSED') then
    raise exception 'Incident is % and cannot be moved further', v_incident.status;
  end if;
  if p_new_status in ('RESOLVED', 'CLOSED') then
    raise exception 'Use resolve_incident() to resolve or close an incident';
  end if;

  v_event_type := public._incident_status_audit_event(p_new_status);
  if v_event_type is null then
    raise exception 'No audit event mapping for incident status %; add one before allowing this transition', p_new_status;
  end if;

  v_previous_status := v_incident.status;

  update public.incidents set status = p_new_status where id = p_incident_id returning * into v_incident;

  perform public.log_audit_event(
    v_incident.organization_id, v_event_type, 'incident', p_incident_id,
    jsonb_build_object('status', v_previous_status),
    jsonb_build_object('status', p_new_status)
  );

  return v_incident;
end;
$$;

create or replace function public.resolve_incident(p_incident_id uuid, p_resolution_notes text, p_close boolean default false)
returns public.incidents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_incident public.incidents;
  v_previous_status public.incident_status;
begin
  if p_resolution_notes is null or btrim(p_resolution_notes) = '' then
    raise exception 'Resolution notes are required';
  end if;

  select * into v_incident from public.incidents where id = p_incident_id for update;
  if v_incident is null then
    raise exception 'Incident % not found', p_incident_id;
  end if;
  if v_incident.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_incident.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to resolve this incident';
  end if;
  if v_incident.status = 'CLOSED' then
    raise exception 'Incident is already CLOSED';
  end if;
  if p_close and v_incident.status <> 'RESOLVED' then
    raise exception 'Incident must be RESOLVED before it can be CLOSED (current status: %)', v_incident.status;
  end if;
  if not p_close and v_incident.status = 'RESOLVED' then
    raise exception 'Incident is already RESOLVED';
  end if;

  v_previous_status := v_incident.status;

  update public.incidents
  set status = (case when p_close then 'CLOSED' else 'RESOLVED' end)::public.incident_status,
      resolved_by = auth.uid(),
      resolved_at = now(),
      resolution_notes = p_resolution_notes
  where id = p_incident_id
  returning * into v_incident;

  perform public.log_audit_event(
    v_incident.organization_id,
    (case when p_close then 'INCIDENT_CLOSED' else 'INCIDENT_RESOLVED' end)::public.audit_event_type,
    'incident', p_incident_id,
    jsonb_build_object('status', v_previous_status),
    jsonb_build_object('status', v_incident.status, 'resolution_notes', p_resolution_notes)
  );

  return v_incident;
end;
$$;
