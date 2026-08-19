import { Badge } from "@/components/ui/Badge";
import type { IncidentStatus } from "@/types/database";

const toneByStatus: Record<IncidentStatus, "pass" | "fail" | "warning" | "neutral" | "info"> = {
  DETECTED: "fail",
  ALERTED: "fail",
  ACKNOWLEDGED: "warning",
  REPLACEMENT_DISPATCHED: "info",
  REPLACEMENT_RECEIVED: "info",
  QUARANTINE_IN_PROGRESS: "warning",
  NCR_OPEN: "warning",
  RESOLVED: "pass",
  CLOSED: "neutral",
};

export function IncidentStatusBadge({ status }: { status: IncidentStatus }) {
  return <Badge tone={toneByStatus[status]}>{status.replace(/_/g, " ")}</Badge>;
}
