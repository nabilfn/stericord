import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Bell } from "lucide-react";
import { listNotifications, markNotificationRead } from "@/features/notifications/api";
import { useNotificationsRealtime } from "@/features/notifications/useNotificationsRealtime";
import { useAuth } from "@/contexts/AuthContext";
import { Badge } from "@/components/ui/Badge";
import { cn } from "@/utils/cn";

const priorityTone: Record<string, "neutral" | "warning" | "fail" | "info"> = {
  LOW: "neutral",
  MEDIUM: "info",
  HIGH: "warning",
  CRITICAL: "fail",
};

export function NotificationBell() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const queryClient = useQueryClient();

  useNotificationsRealtime(user?.id);

  const { data: notifications } = useQuery({
    queryKey: ["notifications"],
    queryFn: listNotifications,
  });

  const markRead = useMutation({
    mutationFn: markNotificationRead,
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["notifications"] }),
  });

  const unreadCount = notifications?.filter((n) => !n.is_read).length ?? 0;

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="relative rounded-full p-2 text-slate-500 hover:bg-slate-100 hover:text-slate-700"
        aria-label="Notifications"
      >
        <Bell size={18} />
        {unreadCount > 0 && (
          <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-fail px-1 text-[10px] font-semibold text-white">
            {unreadCount}
          </span>
        )}
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-40" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 w-80 rounded-lg border border-slate-200 bg-white shadow-lg">
            <div className="border-b border-slate-100 px-4 py-3 text-sm font-semibold text-slate-900">
              Notifications
            </div>
            <div className="max-h-96 overflow-y-auto">
              {(!notifications || notifications.length === 0) && (
                <p className="px-4 py-6 text-center text-sm text-slate-400">No notifications yet.</p>
              )}
              {notifications?.map((n) => (
                <button
                  key={n.id}
                  onClick={() => !n.is_read && markRead.mutate(n.id)}
                  className={cn(
                    "block w-full border-b border-slate-50 px-4 py-3 text-left text-sm hover:bg-slate-50",
                    !n.is_read && "bg-sc-blue-light/40",
                  )}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium text-slate-900">{n.title}</span>
                    <Badge tone={priorityTone[n.priority] ?? "neutral"}>{n.priority}</Badge>
                  </div>
                  {n.body && <p className="mt-1 text-xs text-slate-500">{n.body}</p>}
                  <p className="mt-1 text-xs text-slate-400">{new Date(n.created_at).toLocaleString()}</p>
                </button>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
