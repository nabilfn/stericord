import { supabase } from "@/services/supabaseClient";
import type { AppNotification } from "@/types/database";

export async function listNotifications(): Promise<AppNotification[]> {
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []) as AppNotification[];
}

export async function markNotificationRead(id: string): Promise<AppNotification> {
  const { data, error } = await supabase.rpc("mark_notification_read", { p_notification_id: id });
  if (error) throw error;
  return data as AppNotification;
}
