import { supabase } from "@/services/supabaseClient";
import type { AuditChainIssue, AuditEvent } from "@/types/database";

export interface AuditEventFilters {
  entityType?: string;
  eventType?: string;
  fromDate?: string;
  toDate?: string;
}

export async function listAuditEvents(filters: AuditEventFilters = {}): Promise<AuditEvent[]> {
  let query = supabase.from("audit_events").select("*").order("occurred_at", { ascending: false }).limit(200);

  if (filters.entityType) query = query.eq("entity_type", filters.entityType);
  if (filters.eventType) query = query.eq("event_type", filters.eventType);
  if (filters.fromDate) query = query.gte("occurred_at", filters.fromDate);
  if (filters.toDate) query = query.lte("occurred_at", filters.toDate);

  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as AuditEvent[];
}

export async function listDistinctEntityTypes(): Promise<string[]> {
  const { data, error } = await supabase.from("audit_events").select("entity_type").limit(1000);
  if (error) throw error;
  return Array.from(new Set((data ?? []).map((r) => r.entity_type as string))).sort();
}

export async function verifyAuditChain(organizationId: string): Promise<AuditChainIssue[]> {
  const { data, error } = await supabase.rpc("verify_audit_chain", { p_organization_id: organizationId });
  if (error) throw error;
  return (data ?? []) as AuditChainIssue[];
}
