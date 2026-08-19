import { Badge } from "@/components/ui/Badge";
import type { PackStatus } from "@/types/database";

const toneByStatus: Record<PackStatus, "pass" | "fail" | "warning" | "neutral" | "info"> = {
  PACKED: "neutral",
  STERILIZING: "info",
  PENDING_VERIFICATION: "warning",
  RELEASED: "pass",
  QUARANTINED: "fail",
  RECALLED: "fail",
  USED: "neutral",
  EXPIRED: "neutral",
};

export function PackStatusBadge({ status }: { status: PackStatus }) {
  return <Badge tone={toneByStatus[status]}>{status.replace(/_/g, " ")}</Badge>;
}
