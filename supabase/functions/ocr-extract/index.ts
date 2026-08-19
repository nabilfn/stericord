// SteriCord Phase 5: OCR / Document AI.
//
// Pipeline (master prompt section 34): Camera Capture -> OpenCV
// Preprocessing (Phase 4's client-side quality gate already ran before this
// evidence file could exist) -> Document AI OCR -> Structured Extraction ->
// Human Confirmation. This function is the "Document AI OCR -> Structured
// Extraction" step; confirm_ocr_extraction() (a Postgres function) is the
// human-confirmation step, and its output -- never this function's -- is
// what the rest of the system may treat as authoritative.
//
// Auth model: the Supabase edge runtime verifies the caller's JWT before
// this code runs (config.toml default verify_jwt = true). We use that JWT
// to read evidence_files under normal RLS (proving the caller can actually
// see this file), then switch to the service-role client -- which this
// operation genuinely needs, since it must read the private "evidence"
// bucket and write a row no client-side INSERT policy grants -- for the
// storage download and the ocr_extractions insert.
//
// If GOOGLE_CLOUD_PROJECT_ID / DOCUMENT_AI_PROCESSOR_ID /
// GOOGLE_SERVICE_ACCOUNT_KEY_JSON aren't set (true in this environment --
// there are no real GCP credentials here), this returns a NOT_CONFIGURED
// row instead of throwing, so the human-confirmation UI still has
// something coherent to show.

import { createClient } from "npm:@supabase/supabase-js@2";
import { getAccessToken } from "./google_auth.ts";
import { extractCycleFields } from "./field_extraction.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const { evidence_file_id } = (await req.json()) as { evidence_file_id?: string };
    if (!evidence_file_id) {
      return jsonResponse({ error: "evidence_file_id is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Scoped to the caller: fails closed if RLS wouldn't let them see this row.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: evidenceFile, error: evidenceError } = await callerClient
      .from("evidence_files")
      .select("*")
      .eq("id", evidence_file_id)
      .single();

    if (evidenceError || !evidenceFile) {
      return jsonResponse({ error: "Evidence file not found or not accessible" }, 404);
    }

    const {
      data: { user },
    } = await callerClient.auth.getUser();

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Logged via callerClient (not adminClient) so auth.uid() inside
    // log_audit_event() resolves to the real requesting user instead of
    // null -- the service-role JWT has no "sub" claim to attribute to.
    await logAudit(callerClient, evidenceFile.organization_id, "OCR_EXTRACTION_REQUESTED", evidence_file_id);

    const projectId = Deno.env.get("GOOGLE_CLOUD_PROJECT_ID");
    const processorId = Deno.env.get("DOCUMENT_AI_PROCESSOR_ID");
    const serviceAccountKeyJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_KEY_JSON");
    const location = Deno.env.get("DOCUMENT_AI_LOCATION") ?? "us";

    if (!projectId || !processorId || !serviceAccountKeyJson) {
      const { data: row, error } = await adminClient
        .from("ocr_extractions")
        .insert({
          organization_id: evidenceFile.organization_id,
          evidence_file_id,
          status: "NOT_CONFIGURED",
          error_message:
            "Document AI is not configured in this environment (GOOGLE_CLOUD_PROJECT_ID / DOCUMENT_AI_PROCESSOR_ID / GOOGLE_SERVICE_ACCOUNT_KEY_JSON not set).",
          requested_by: user?.id,
        })
        .select()
        .single();
      if (error) throw error;
      return jsonResponse(row, 200);
    }

    // Download the image from the private bucket (service role bypasses storage RLS).
    const { data: fileBlob, error: downloadError } = await adminClient.storage
      .from(evidenceFile.bucket)
      .download(evidenceFile.object_path);
    if (downloadError || !fileBlob) {
      throw new Error(`Failed to download evidence file: ${downloadError?.message}`);
    }
    const bytes = new Uint8Array(await fileBlob.arrayBuffer());
    const base64Content = base64Encode(bytes);

    let status: "COMPLETED" | "FAILED" = "COMPLETED";
    let rawText: string | null = null;
    let confidence: number | null = null;
    let errorMessage: string | null = null;
    let extractedFields: Record<string, unknown> = {};

    try {
      const accessToken = await getAccessToken(serviceAccountKeyJson);
      const endpoint = `https://${location}-documentai.googleapis.com/v1/projects/${projectId}/locations/${location}/processors/${processorId}:process`;

      const docAiResponse = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          rawDocument: {
            content: base64Content,
            mimeType: evidenceFile.mime_type ?? "image/jpeg",
          },
        }),
      });

      if (!docAiResponse.ok) {
        throw new Error(`Document AI request failed (${docAiResponse.status}): ${await docAiResponse.text()}`);
      }

      const result = (await docAiResponse.json()) as {
        document?: { text?: string; textStyles?: unknown; pages?: Array<{ confidence?: number }> };
      };
      rawText = result.document?.text ?? "";
      confidence = result.document?.pages?.[0]?.confidence ?? null;
      extractedFields = extractCycleFields(rawText) as unknown as Record<string, unknown>;
    } catch (err) {
      status = "FAILED";
      errorMessage = err instanceof Error ? err.message : String(err);
    }

    const { data: row, error: insertError } = await adminClient
      .from("ocr_extractions")
      .insert({
        organization_id: evidenceFile.organization_id,
        evidence_file_id,
        status,
        raw_text: rawText,
        extracted_fields: extractedFields,
        confidence,
        error_message: errorMessage,
        requested_by: user?.id,
      })
      .select()
      .single();
    if (insertError) throw insertError;

    if (status === "COMPLETED") {
      await logAudit(callerClient, evidenceFile.organization_id, "OCR_EXTRACTION_COMPLETED", evidence_file_id);
    }

    return jsonResponse(row, 200);
  } catch (err) {
    console.error("ocr-extract error:", err);
    return jsonResponse({ error: err instanceof Error ? err.message : "Unknown error" }, 500);
  }
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

// deno-lint-ignore no-explicit-any
async function logAudit(client: any, organizationId: string, eventType: string, entityId: string) {
  await client.rpc("log_audit_event", {
    p_organization_id: organizationId,
    p_event_type: eventType,
    p_entity_type: "evidence_file",
    p_entity_id: entityId,
    p_previous_state: null,
    p_new_state: null,
  });
}
