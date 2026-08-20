import { useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { ShieldCheck, ShieldAlert } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Select } from "@/components/ui/Select";
import { Input, Label } from "@/components/ui/Input";
import { Badge } from "@/components/ui/Badge";
import { useAuth } from "@/contexts/AuthContext";
import { listAuditEvents, listDistinctEntityTypes, verifyAuditChain, type AuditEventFilters } from "@/features/audit/api";

export function AuditTrailPage() {
  const { profile } = useAuth();
  const [filters, setFilters] = useState<AuditEventFilters>({});

  const entityTypesQuery = useQuery({ queryKey: ["audit-entity-types"], queryFn: listDistinctEntityTypes });
  const eventsQuery = useQuery({
    queryKey: ["audit-events", filters],
    queryFn: () => listAuditEvents(filters),
  });

  const chainMutation = useMutation({
    mutationFn: () => verifyAuditChain(profile!.organization_id),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-slate-900">Audit Trail</h1>
          <p className="text-sm text-slate-500">Immutable, hash-chained record of every compliance-relevant event.</p>
        </div>
        <Button
          variant="secondary"
          disabled={chainMutation.isPending}
          onClick={() => chainMutation.mutate()}
        >
          <ShieldCheck size={16} />
          {chainMutation.isPending ? "Verifying…" : "Verify Chain Integrity"}
        </Button>
      </div>

      {chainMutation.isSuccess && (
        <Card>
          <CardContent>
            {chainMutation.data.length === 0 ? (
              <div className="flex items-center gap-2 text-sm text-pass">
                <ShieldCheck size={16} />
                <span>Chain intact — every event's hash matches a recomputation from its own stored content.</span>
              </div>
            ) : (
              <div className="space-y-2">
                <div className="flex items-center gap-2 text-sm font-semibold text-fail">
                  <ShieldAlert size={16} />
                  <span>{chainMutation.data.length} integrity issue(s) found</span>
                </div>
                <ul className="space-y-1 text-xs text-fail">
                  {chainMutation.data.map((issue) => (
                    <li key={issue.out_event_id}>
                      {issue.out_event_type} at {new Date(issue.out_occurred_at).toLocaleString()} — {issue.out_issue}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </CardContent>
        </Card>
      )}

      <Card>
        <CardContent className="flex flex-wrap items-end gap-3">
          <div>
            <Label htmlFor="filter_entity_type">Entity type</Label>
            <Select
              id="filter_entity_type"
              className="max-w-[200px]"
              value={filters.entityType ?? ""}
              onChange={(e) => setFilters((f) => ({ ...f, entityType: e.target.value || undefined }))}
            >
              <option value="">All</option>
              {entityTypesQuery.data?.map((t) => (
                <option key={t} value={t}>
                  {t.replace(/_/g, " ")}
                </option>
              ))}
            </Select>
          </div>
          <div>
            <Label htmlFor="filter_from">From</Label>
            <Input
              id="filter_from"
              type="date"
              onChange={(e) => setFilters((f) => ({ ...f, fromDate: e.target.value || undefined }))}
            />
          </div>
          <div>
            <Label htmlFor="filter_to">To</Label>
            <Input
              id="filter_to"
              type="date"
              onChange={(e) => setFilters((f) => ({ ...f, toDate: e.target.value || undefined }))}
            />
          </div>
          {(filters.entityType || filters.fromDate || filters.toDate) && (
            <Button variant="ghost" onClick={() => setFilters({})}>
              Clear filters
            </Button>
          )}
        </CardContent>
      </Card>

      <Card className="overflow-hidden">
        <CardHeader>
          <CardTitle>Events ({eventsQuery.data?.length ?? 0})</CardTitle>
        </CardHeader>
        {eventsQuery.isLoading && <p className="p-5 text-sm text-slate-500">Loading…</p>}
        {eventsQuery.data && eventsQuery.data.length > 0 && (
          <table className="min-w-full divide-y divide-slate-100">
            <thead className="bg-slate-50">
              <tr>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">Event</th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">Entity</th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">When</th>
                <th className="px-5 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-500">Hash</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {eventsQuery.data.map((event) => (
                <tr key={event.id} className="hover:bg-slate-50">
                  <td className="px-5 py-3 text-sm font-medium text-slate-900">{event.event_type.replace(/_/g, " ")}</td>
                  <td className="px-5 py-3 text-sm text-slate-700">{event.entity_type.replace(/_/g, " ")}</td>
                  <td className="px-5 py-3 text-sm text-slate-700">{new Date(event.occurred_at).toLocaleString()}</td>
                  <td className="px-5 py-3">
                    <Badge tone="neutral" className="font-mono text-[10px]">
                      {event.event_hash.slice(0, 12)}…
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
