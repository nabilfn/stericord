// Gemini multimodal indicator analysis. Auth is a plain API key (query
// param), unlike Document AI's service-account OAuth2 flow in
// ocr-extract/ -- Gemini's Generative Language API is designed for exactly
// this kind of simple server-side key usage.

export interface GeminiAnalysisResult {
  suggested_result: "PASS" | "FAIL" | "UNDETERMINED";
  confidence: number;
  observations: string[];
}

const INDICATOR_GUIDANCE: Record<string, string> = {
  BOWIE_DICK: "A Bowie-Dick test sheet. PASS requires a uniform, complete color change across the entire sheet with no lighter patches (which would indicate incomplete air removal).",
  CHEMICAL_INDICATOR: "A Type 4/5/6 chemical indicator strip. PASS requires the indicator ink to have fully changed to the reference color shown on its packaging, with no partial or streaky change.",
  BI_TRAY: "A biological indicator (BI) vial or tray, typically with a color-change growth medium. A clear/unchanged medium after incubation typically indicates PASS (no viable spores); a color change (often to yellow) indicates FAIL (growth detected). If the image doesn't show enough of the medium to judge color, say UNDETERMINED.",
  OT_INDICATOR: "A point-of-use chemical indicator strip inside an instrument pack, checked at the operating theatre before use. PASS requires full, uniform color change to the reference color.",
  WASHER_TEST: "A washer-disinfector test soil indicator. PASS requires the test soil to be fully removed/cleaned with no visible residue.",
};

function buildPrompt(indicatorType: string): string {
  const guidance = INDICATOR_GUIDANCE[indicatorType] ?? "A sterilization process indicator.";
  return `You are assisting a certified CSSD (Central Sterile Supply Department) technician in reading a sterilization process indicator. You are NOT making a clinical or patient-safety decision -- a qualified human always makes the final call. Your job is only to describe what you observe and offer a cautious suggestion.

Indicator type: ${indicatorType}
${guidance}

Look at the attached photo and respond with:
- suggested_result: "PASS" if the indicator clearly and unambiguously shows a passing result, "FAIL" if it clearly and unambiguously shows a failing result, or "UNDETERMINED" if the image is unclear, poorly lit, out of frame, ambiguous, or you are not highly confident either way. When genuinely uncertain, always choose UNDETERMINED rather than guessing.
- confidence: your confidence in suggested_result, from 0.0 (no confidence) to 1.0 (certain), based only on what is visible in the image.
- observations: 1-4 short, specific, factual observations about what you see (e.g. color, uniformity, any visible defects) that a human reviewer can use to make their own judgment. Do not state or imply that sterility is confirmed or that the pack is safe to use -- describe the indicator only.

Respond with the suggested_result/confidence/observations JSON only.`;
}

export async function analyzeIndicatorImage(
  apiKey: string,
  model: string,
  base64Image: string,
  mimeType: string,
  indicatorType: string,
): Promise<{ result: GeminiAnalysisResult; rawResponse: unknown }> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const body = {
    contents: [
      {
        parts: [
          { text: buildPrompt(indicatorType) },
          { inline_data: { mime_type: mimeType, data: base64Image } },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: {
          suggested_result: { type: "STRING", enum: ["PASS", "FAIL", "UNDETERMINED"] },
          confidence: { type: "NUMBER" },
          observations: { type: "ARRAY", items: { type: "STRING" } },
        },
        required: ["suggested_result", "confidence", "observations"],
      },
    },
  };

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Gemini request failed (${response.status}): ${await response.text()}`);
  }

  const json = (await response.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };

  const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini response had no candidate text");
  }

  const parsed = JSON.parse(text) as GeminiAnalysisResult;
  if (!["PASS", "FAIL", "UNDETERMINED"].includes(parsed.suggested_result)) {
    throw new Error(`Gemini returned an unexpected suggested_result: ${parsed.suggested_result}`);
  }

  return { result: parsed, rawResponse: json };
}
