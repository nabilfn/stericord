-- SteriCord Phase 3: enable Realtime broadcast for notifications.
-- `realtime.enabled = true` in config.toml only starts the Realtime
-- service; each table still needs to be added to the supabase_realtime
-- publication before postgres_changes events are broadcast for it.

alter publication supabase_realtime add table public.notifications;
