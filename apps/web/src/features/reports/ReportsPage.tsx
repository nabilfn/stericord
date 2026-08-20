import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { FileDown, Wrench, Layers, AlertTriangle, type LucideIcon } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Select } from "@/components/ui/Select";
import { Label } from "@/components/ui/Input";
import { listEquipment } from "@/features/equipment/api";
import { listCycles } from "@/features/cycles/api";
import { listIncidents } from "@/features/incidents/api";
import { downloadReport, type ReportKind } from "@/features/reports/api";

interface ReportSectionProps {
  icon: LucideIcon;
  title: string;
  description: string;
  kind: ReportKind;
  options: { value: string; label: string }[];
  loading: boolean;
  filenamePrefix: string;
}

function ReportSection({ icon: Icon, title, description, kind, options, loading, filenamePrefix }: ReportSectionProps) {
  const [selected, setSelected] = useState("");
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: () => {
      const label = options.find((o) => o.value === selected)?.label ?? selected;
      return downloadReport(kind, selected, `${filenamePrefix}-${label}`.replace(/[^a-zA-Z0-9-_]/g, "_"));
    },
    onError: (err) => setError(err instanceof Error ? err.message : "Failed to generate report"),
  });

  return (
    <Card>
      <CardHeader className="flex flex-row items-center gap-2">
        <Icon size={16} />
        <div>
          <CardTitle>{title}</CardTitle>
          <p className="text-xs text-slate-500">{description}</p>
        </div>
      </CardHeader>
      <CardContent className="flex items-end gap-2">
        <div className="flex-1">
          <Label htmlFor={`${kind}-select`}>Select {title.toLowerCase()}</Label>
          <Select
            id={`${kind}-select`}
            value={selected}
            onChange={(e) => {
              setSelected(e.target.value);
              setError(null);
            }}
            disabled={loading}
          >
            <option value="">{loading ? "Loading…" : "Choose…"}</option>
            {options.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </Select>
        </div>
        <Button disabled={!selected || mutation.isPending} onClick={() => mutation.mutate()}>
          <FileDown size={16} />
          {mutation.isPending ? "Generating…" : "Download PDF"}
        </Button>
      </CardContent>
      {error && <p className="px-5 pb-4 text-sm text-fail">{error}</p>}
    </Card>
  );
}

export function ReportsPage() {
  const equipmentQuery = useQuery({ queryKey: ["equipment"], queryFn: listEquipment });
  const cyclesQuery = useQuery({ queryKey: ["cycles"], queryFn: listCycles });
  const incidentsQuery = useQuery({ queryKey: ["incidents"], queryFn: listIncidents });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-slate-900">Reports</h1>
        <p className="text-sm text-slate-500">
          Generate compliance PDFs. Each report is rendered from your own authorized view of the data — nothing
          you couldn't already see in the app — and every export is recorded in the Audit Trail.
        </p>
      </div>

      <ReportSection
        icon={Wrench}
        title="Equipment Report"
        description="Details, status history, and cycles run on a piece of equipment."
        kind="equipment"
        filenamePrefix="equipment"
        loading={equipmentQuery.isLoading}
        options={(equipmentQuery.data ?? []).map((e) => ({ value: e.id, label: e.equipment_code }))}
      />

      <ReportSection
        icon={Layers}
        title="Cycle Report"
        description="Full traceability sheet: parameters, packs, evidence hashes, verification, and audit trail."
        kind="cycle"
        filenamePrefix="cycle"
        loading={cyclesQuery.isLoading}
        options={(cyclesQuery.data ?? []).map((c) => ({ value: c.id, label: c.cycle_number }))}
      />

      <ReportSection
        icon={AlertTriangle}
        title="Incident Report"
        description="Incident summary, resolution notes, and any linked quarantine."
        kind="incident"
        filenamePrefix="incident"
        loading={incidentsQuery.isLoading}
        options={(incidentsQuery.data ?? []).map((i) => ({
          value: i.id,
          label: `${i.source_type.replace(/_/g, " ")} — ${new Date(i.detected_at).toLocaleDateString()}`,
        }))}
      />

      <p className="text-xs text-slate-400">
        Evidence sheets (per-file integrity + OCR/AI details) are available from the Download button next to each
        file in a cycle or pack's Evidence section.
      </p>
    </div>
  );
}
