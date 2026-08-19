// SteriCord Phase 6: multimodal AI (Gemini) indicator analysis.
//
// Master prompt section 35 (AIProvider), section 36 (confidence routing),
// section 38 (AI safety -- AI may assist/classify/recommend/flag; it may
// never autonomously release a pack, declare a result, unlock equipment,
// or remove quarantine). This function is the "AI generates recommendation
// / confidence is recorded" step of section 4's pipeline; a human always
// makes the authoritative call afterward through verify_cycle() or
// record_point_of_use_verification() (Phase 2/3, extended in this phase's
// migration to optionally link back to the ai_analyses row that informed
// the human's decision).
//
// Same auth model as ocr-extract/: the edge runtime verifies the caller's
// JWT, we use it to read evidence_files under RLS, then the service-role
// client for the private-bucket download and the ai_analyses insert (no
// client-side INSERT policy grants one, by design).
//
// If GEMINI_API_KEY isn't set (true in this environment), this returns a
// NOT_CONFIGURED row instead of throwing.

import { createClient } from "npm:@supabase/supabase-js@2";
import { analyzeIndicatorImage } from "./gemini_client.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Section 36: HIGH -> show recommendation, MEDIUM -> flag for secondary
// review, LOW -> forced UNDETERMINED regardless of what the model said.
// Enforced here, server-side, so a client bug or a modified request body
// can't surface a confident-looking suggestion from a low-confidence read.
const HIGH_CONFIDENCE_THRESHOLD = 0.85;
const MEDIUM_CONFIDENCE_THRESHOLD = 0.6;

function bandFor(confidence: number): "HIGH" | "MEDIUM" | "LOW" {
  if (confidence >= HIGH_CONFIDENCE_THRESHOLD) return "HIGH";
  if (confidence >= MEDIUM_CONFIDENCE_THRESHOLD) return "MEDIUM";
  return "LOW";
}

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
    // log_audit_event() resolves to the real requesting user -- the
    // service-role JWT has no "sub" claim to attribute to.
    await callerClient.rpc("log_audit_event", {
      p_organization_id: evidenceFile.organization_id,
      p_event_type: "AI_ANALYSIS_REQUESTED",
      p_entity_type: "evidence_file",
      p_entity_id: evidence_file_id,
      p_previous_state: null,
      p_new_state: null,
    });

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";

    if (!apiKey) {
      const { data: row, error } = await adminClient
        .from("ai_analyses")
        .insert({
          organization_id: evidenceFile.organization_id,
          evidence_file_id,
          status: "NOT_CONFIGURED",
          indicator_type: evidenceFile.evidence_type,
          error_message: "Gemini is not configured in this environment (GEMINI_API_KEY not set).",
          requested_by: user?.id,
        })
        .select()
        .single();
      if (error) throw error;
      return jsonResponse(row, 200);
    }

    const { data: fileBlob, error: downloadError } = await adminClient.storage
      .from(evidenceFile.bucket)
      .download(evidenceFile.object_path);
    if (downloadError || !fileBlob) {
      throw new Error(`Failed to download evidence file: ${downloadError?.message}`);
    }
    const bytes = new Uint8Array(await fileBlob.arrayBuffer());
    const base64Image = base64Encode(bytes);

    let status: "COMPLETED" | "FAILED" = "COMPLETED";
    let suggestedResult: string | null = null;
    let confidence: number | null = null;
    let confidenceBand: "HIGH" | "MEDIUM" | "LOW" | null = null;
    let observations: string[] = [];
    let rawResponse: unknown = null;
    let errorMessage: string | null = null;

    try {
      const { result, rawResponse: raw } = await analyzeIndicatorImage(
        apiKey,
        model,
        base64Image,
        evidenceFile.mime_type ?? "image/jpeg",
        evidenceFile.evidence_type,
      );
      rawResponse = raw;
      confidence = Math.max(0, Math.min(1, result.confidence));
      confidenceBand = bandFor(confidence);
      observations = result.observations ?? [];

      // Section 36, enforced: a LOW-confidence read is never allowed to
      // present as a confident PASS/FAIL, no matter what the model said.
      suggestedResult = confidenceBand === "LOW" ? "UNDETERMINED" : result.suggested_result;
    } catch (err) {
      status = "FAILED";
      errorMessage = err instanceof Error ? err.message : String(err);
    }

    const { data: row, error: insertError } = await adminClient
      .from("ai_analyses")
      .insert({
        organization_id: evidenceFile.organization_id,
        evidence_file_id,
        model,
        status,
        indicator_type: evidenceFile.evidence_type,
        suggested_result: suggestedResult,
        confidence,
        confidence_band: confidenceBand,
        observations,
        raw_response: rawResponse,
        error_message: errorMessage,
        requested_by: user?.id,
      })
      .select()
      .single();
    if (insertError) throw insertError;

    if (status === "COMPLETED") {
      await callerClient.rpc("log_audit_event", {
        p_organization_id: evidenceFile.organization_id,
        p_event_type: "AI_ANALYSIS_COMPLETED",
        p_entity_type: "evidence_file",
        p_entity_id: evidence_file_id,
        p_previous_state: null,
        p_new_state: { suggested_result: suggestedResult, confidence_band: confidenceBand },
      });
    }

    return jsonResponse(row, 200);
  } catch (err) {
    console.error("gemini-analyze error:", err);
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
