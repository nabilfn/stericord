-- SteriCord QA remediation D-02 (FF-06): quarantine_pack() moved a pack to
-- QUARANTINED and logged PACK_QUARANTINED without ever inserting into
-- public.quarantines -- the table that's actually supposed to represent
-- "there is an open hold on this pack, here is why, here is who released it
-- and when." Nothing downstream (the Quarantine list screen, incident
-- linkage, compliance reports) can see a hold that only exists as a status
-- enum value.
--
-- The whole function body already runs as one statement inside whatever
-- transaction the RPC call is wrapped in -- a single plpgsql function
-- invocation is atomic by construction, there is no partial-commit
-- possibility to guard against here. The real gap was a missing INSERT,
-- not a missing transaction boundary.
--
-- What DOES need explicit handling is the race the plain SELECT left open:
-- two concurrent quarantine_pack() calls could both read status =
-- PENDING_VERIFICATION before either commits its UPDATE, both pass the
-- status check, and both proceed -- two quarantine rows and two audit
-- events for what should be one hold. `for update` takes a row lock on the
-- first SELECT, so the second concurrent call blocks until the first
-- transaction commits, then re-reads the now-QUARANTINED status and is
-- correctly rejected by the existing status check -- no new idempotency
-- table needed, the existing "pack must be PENDING_VERIFICATION or
-- RELEASED" guard already does the rejection once concurrent calls can no
-- longer race past it simultaneously.

create or replace function public.quarantine_pack(p_pack_id uuid, p_reason text)
returns public.instrument_packs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pack public.instrument_packs;
  v_quarantine public.quarantines;
begin
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to quarantine a pack';
  end if;

  select * into v_pack from public.instrument_packs where id = p_pack_id for update;
  if v_pack is null then
    raise exception 'Pack % not found', p_pack_id;
  end if;
  if v_pack.organization_id <> public.current_organization_id() and not public.is_system_admin() then
    raise exception 'Not authorized for this organization';
  end if;
  if not (public.user_has_role(v_pack.organization_id, array['HOSPITAL_ADMIN','CSSD_SUPERVISOR']::public.user_role[]) or public.is_system_admin()) then
    raise exception 'Only a CSSD supervisor or hospital admin can quarantine a pack';
  end if;
  if v_pack.status not in ('PENDING_VERIFICATION', 'RELEASED') then
    raise exception 'Pack cannot be quarantined from status %', v_pack.status;
  end if;

  update public.instrument_packs
  set status = 'QUARANTINED'
  where id = p_pack_id
  returning * into v_pack;

  insert into public.quarantines (
    organization_id, scope_type, scope_id, reason, status, initiated_by
  ) values (
    v_pack.organization_id, 'PACK', p_pack_id, p_reason, 'ACTIVE', auth.uid()
  )
  returning * into v_quarantine;

  perform public.log_audit_event(
    v_pack.organization_id, 'PACK_QUARANTINED', 'instrument_pack', p_pack_id,
    null, jsonb_build_object('pack_status', v_pack.status, 'reason', p_reason, 'quarantine_id', v_quarantine.id)
  );

  perform public.log_audit_event(
    v_pack.organization_id, 'QUARANTINE_STARTED', 'instrument_pack', p_pack_id,
    null, jsonb_build_object('quarantine_id', v_quarantine.id, 'reason', p_reason)
  );

  return v_pack;
end;
$$;

comment on function public.quarantine_pack is 'Moves a pack to QUARANTINED, opens the corresponding public.quarantines hold, and audits both -- one call, one hold, one pair of audit events. `for update` on the initial read closes a race where two concurrent calls could otherwise both pass the status check and create duplicate holds.';
