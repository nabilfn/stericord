-- SteriCord Phase 3: incident/quarantine management functions.
-- The master prompt defines the full incident_status vocabulary (section
-- 26) but not a strict transition graph between all nine states, so
-- advance_incident_status() only enforces what's unambiguous: RESOLVED and
-- CLOSED are terminal, and only a CSSD supervisor/hospital admin may act.
-- acknowledge_incident() and resolve_incident() are the two transitions the
-- spec does pin down precisely.

create or replace function public.acknowledge_incident(p_incident_id uuid)
returns public.incidents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_incident public.incidents;
begin
  select * into v_incident from public.incidents where id = p_incident_id;
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

  update public.incidents
  set status = 'ACKNOWLEDGED', acknowledged_by = auth.uid(), acknowledged_at = now()
  where id = p_incident_id
  returning * into v_incident;

  return v_incident;
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
begin
  select * into v_incident from public.incidents where id = p_incident_id;
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

  update public.incidents set status = p_new_status where id = p_incident_id returning * into v_incident;

  perform public.log_audit_event(
    v_incident.organization_id, 'INCIDENT_CREATED', 'incident', p_incident_id,
    null, jsonb_build_object('status', p_new_status)
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
begin
  select * into v_incident from public.incidents where id = p_incident_id;
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

  update public.incidents
  set status = (case when p_close then 'CLOSED' else 'RESOLVED' end)::public.incident_status,
      resolved_by = auth.uid(),
      resolved_at = now(),
      resolution_notes = p_resolution_notes
  where id = p_incident_id
  returning * into v_incident;

  return v_incident;
end;
$$;

create or replace function public.release_quarantine(p_quarantine_id uuid, p_release_reason text)
returns public.quarantines
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quarantine public.quarantines;
begin
  select * into v_quarantine from public.quarantines where id = p_quarantine_id;
  if v_quarantine is null then
    raise exception 'Quarantine % not found', p_quarantine_id;
  end if;
  if v_quarantine.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_quarantine.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Not authorized to release a quarantine';
  end if;
  if v_quarantine.status <> 'ACTIVE' then
    raise exception 'Quarantine is not ACTIVE (current status: %)', v_quarantine.status;
  end if;

  update public.quarantines
  set status = 'RELEASED', released_by = auth.uid(), released_at = now(), release_reason = p_release_reason
  where id = p_quarantine_id
  returning * into v_quarantine;

  perform public.log_audit_event(
    v_quarantine.organization_id, 'QUARANTINE_RELEASED', v_quarantine.scope_type::text, v_quarantine.scope_id,
    null, jsonb_build_object('quarantine_id', p_quarantine_id, 'release_reason', p_release_reason)
  );

  return v_quarantine;
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notification public.notifications;
begin
  update public.notifications
  set is_read = true, read_at = now()
  where id = p_notification_id and recipient_user_id = auth.uid()
  returning * into v_notification;

  if v_notification is null then
    raise exception 'Notification % not found for current user', p_notification_id;
  end if;

  return v_notification;
end;
$$;
