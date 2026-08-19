-- SteriCord Phase 3: notifications.
-- One row per recipient (fan-out happens at creation time in
-- notify_roles(), next migration) rather than one row per role -- this
-- keeps "mark as read" a trivial per-row boolean instead of needing
-- per-user read-state tracking on a shared row.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null default 'IN_APP',
  priority public.notification_priority not null default 'MEDIUM',
  title text not null,
  body text,
  related_entity_type text,
  related_entity_id uuid,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.notifications is 'In-app alert, one row per recipient. Delivered to clients via Supabase Realtime on this table.';

create index idx_notifications_recipient on public.notifications(recipient_user_id, is_read);
create index idx_notifications_organization_id on public.notifications(organization_id);

alter table public.notifications enable row level security;

create policy notifications_select on public.notifications
  for select
  using (recipient_user_id = auth.uid() or public.is_system_admin());

create policy notifications_update_own on public.notifications
  for update
  using (recipient_user_id = auth.uid())
  with check (recipient_user_id = auth.uid());
