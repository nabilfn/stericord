import { Badge } from "@/components/ui/Badge";
import type { EquipmentStatus } from "@/types/database";

const toneByStatus: Record<EquipmentStatus, "pass" | "fail" | "warning" | "neutral"> = {
  ACTIVE: "pass",
  LOCKED_OUT: "fail",
  MAINTENANCE: "warning",
  DECOMMISSIONED: "neutral",
};

export function EquipmentStatusBadge({ status }: { status: EquipmentStatus }) {
  return <Badge tone={toneByStatus[status]}>{status.replace("_", " ")}</Badge>;
}
