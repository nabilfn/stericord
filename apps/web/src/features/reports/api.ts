import { supabase } from "@/services/supabaseClient";

const REPORTING_URL = import.meta.env.VITE_REPORTING_SERVICE_URL;

export type ReportKind = "equipment" | "cycle" | "incident" | "evidence";

/**
 * Downloads a PDF from the reporting service (services/reporting, Phase 7)
 * under the current user's own session -- the service re-queries Supabase
 * with this same token, so RLS decides what it's allowed to render. Not a
 * new authorization boundary, just a renderer for whatever the caller could
 * already see.
 */
export async function downloadReport(kind: ReportKind, entityId: string, filenameHint: string): Promise<void> {
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session) throw new Error("Not signed in");

  const response = await fetch(`${REPORTING_URL}/reports/${kind}/${entityId}`, {
    headers: { Authorization: `Bearer ${session.access_token}` },
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`Report generation failed (${response.status}): ${body || response.statusText}`);
  }

  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `${filenameHint}.pdf`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
