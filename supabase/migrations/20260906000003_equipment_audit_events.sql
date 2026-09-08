-- SteriCord QA remediation D-01 (FF-04): equipment create/edit/status-change
-- operations recorded to equipment_status_events (a history table) but
-- never to audit_events (the compliance/hash-chain table) -- the two are
-- not the same thing, and only the second one is what verify_audit_chain()
-- and the compliance reports actually cover.
--
-- Equipment is one of the few tables clients write to directly (INSERT/
-- UPDATE under RLS, not through a SECURITY DEFINER RPC like cycles/packs),
-- so the only place that can log this server-side, unconditionally, is the
-- existing trigger -- a client cannot skip a trigger the way it could skip
-- calling an application-level "please also log this" function.
--
-- The UPDATE trigger previously fired only "after update of
-- operating_status", so a plain metadata edit (location, manufacturer, ...)
-- with no status change never ran this function at all. Broadened to a
-- plain "after update" and the function itself decides what to log --
-- status changes get EQUIPMENT_STATUS_CHANGED, anything else that actually
-- changed gets EQUIPMENT_UPDATED, and the two are mutually exclusive on any
-- one UPDATE so a single client operation never produces two audit rows.

drop trigger if exists trg_equipment_status_update on public.equipment;

create or replace function public.record_equipment_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.equipment_status_events (
      organization_id, equipment_id, previous_status, new_status, changed_by
    ) values (
      new.organization_id, new.id, null, new.operating_status, auth.uid()
    );

    perform public.log_audit_event(
      new.organization_id, 'EQUIPMENT_CREATED', 'equipment', new.id,
      null, to_jsonb(new)
    );

  elsif tg_op = 'UPDATE' then
    if old.operating_status is distinct from new.operating_status then
      insert into public.equipment_status_events (
        organization_id, equipment_id, previous_status, new_status, changed_by
      ) values (
        new.organization_id, new.id, old.operating_status, new.operating_status, auth.uid()
      );

      perform public.log_audit_event(
        new.organization_id, 'EQUIPMENT_STATUS_CHANGED', 'equipment', new.id,
        jsonb_build_object('operating_status', old.operating_status),
        jsonb_build_object('operating_status', new.operating_status)
      );
    elsif old is distinct from new then
      perform public.log_audit_event(
        new.organization_id, 'EQUIPMENT_UPDATED', 'equipment', new.id,
        to_jsonb(old), to_jsonb(new)
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_equipment_status_update
  after update on public.equipment
  for each row execute function public.record_equipment_status_change();

comment on function public.record_equipment_status_change is 'Server-side, trigger-only source of equipment audit coverage -- fires on every INSERT/UPDATE regardless of client behavior, so equipment_status_events and audit_events cannot be bypassed by a client that only knows the table-level RLS INSERT/UPDATE policies. Status changes log EQUIPMENT_STATUS_CHANGED; any other change logs EQUIPMENT_UPDATED; the two never both fire for one operation.';
