import { Badge } from "@/components/ui/Badge";
import type { CycleStatus } from "@/types/database";

const toneByStatus: Record<CycleStatus, "pass" | "fail" | "warning" | "neutral" | "info"> = {
  CREATED: "neutral",
  RUNNING: "info",
  COMPLETED: "info",
  PENDING_VERIFICATION: "warning",
  PASSED: "pass",
  FAILED: "fail",
  QUARANTINED: "fail",
};

export function CycleStatusBadge({ status }: { status: CycleStatus }) {
  return <Badge tone={toneByStatus[status]}>{status.replace(/_/g, " ")}</Badge>;
}
