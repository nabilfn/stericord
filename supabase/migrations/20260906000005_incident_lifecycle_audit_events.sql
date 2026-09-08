-- SteriCord QA remediation D-03 (FF-14): advance_incident_status() logged
-- every transition as 'INCIDENT_CREATED' (a straight copy-paste of the
-- literal from record_point_of_use_verification's actual creation call),
-- and acknowledge_incident()/resolve_incident() never logged anything at
-- all. Source inspection during QA confirmed the hardcoded literal
-- directly.
--
-- One new enum value per real transition the incident_status enum
-- supports (not just the subset FF-14 happened to exercise), so "emit
-- exactly one correctly named audit event for every successful transition"
-- holds for the whole state machine, not only the tested path.

alter type public.audit_event_type add value if not exists 'INCIDENT_ACKNOWLEDGED';
alter type public.audit_event_type add value if not exists 'INCIDENT_REPLACEMENT_DISPATCHED';
alter type public.audit_event_type add value if not exists 'INCIDENT_REPLACEMENT_RECEIVED';
alter type public.audit_event_type add value if not exists 'INCIDENT_QUARANTINE_IN_PROGRESS';
alter type public.audit_event_type add value if not exists 'INCIDENT_NCR_OPEN';
alter type public.audit_event_type add value if not exists 'INCIDENT_RESOLVED';
alter type public.audit_event_type add value if not exists 'INCIDENT_CLOSED';
