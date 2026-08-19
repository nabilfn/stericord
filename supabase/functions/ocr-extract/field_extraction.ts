// Regex-based structured field extraction over Document AI's recognized
// text. There is no custom-trained Document AI entity extractor here (that
// needs a labelled training set via Document AI Workbench, well beyond
// this phase) -- this is a generic OCR processor's plain text, parsed with
// label-pattern heuristics. Thermal receipt formats vary by autoclave
// manufacturer, so this WILL miss fields on formats it hasn't seen; that is
// exactly why the master prompt requires human confirmation before any of
// this is authoritative (section 34).

export interface ExtractedCycleFields {
  cycle_number: string | null;
  temperature: number | null;
  pressure: number | null;
  hold_time_seconds: number | null;
  date: string | null;
  time: string | null;
  machine_identifier: string | null;
  result: string | null;
}

function firstMatch(text: string, patterns: RegExp[]): string | null {
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match?.[1]) return match[1].trim();
  }
  return null;
}

function parseNumber(value: string | null): number | null {
  if (!value) return null;
  const cleaned = value.replace(/[^\d.-]/g, "");
  const num = Number.parseFloat(cleaned);
  return Number.isFinite(num) ? num : null;
}

/** Converts "4 min", "4:30", "270" (assumed seconds) into whole seconds. */
function parseHoldTime(value: string | null): number | null {
  if (!value) return null;
  const minSec = value.match(/(\d+)\s*:\s*(\d+)/);
  if (minSec) return Number(minSec[1]) * 60 + Number(minSec[2]);
  const minutes = value.match(/(\d+(?:\.\d+)?)\s*min/i);
  if (minutes) return Math.round(Number.parseFloat(minutes[1]!) * 60);
  const seconds = value.match(/(\d+)\s*(?:sec|s)\b/i);
  if (seconds) return Number(seconds[1]);
  const bare = value.match(/(\d+)/);
  return bare ? Number(bare[1]) : null;
}

export function extractCycleFields(text: string): ExtractedCycleFields {
  const cycleNumber = firstMatch(text, [
    /cycle\s*(?:no|number|#)?\s*[:\-]?\s*([A-Z0-9\-\/]+)/i,
    /program\s*(?:no|number|#)?\s*[:\-]?\s*([A-Z0-9\-\/]+)/i,
  ]);

  const temperature = parseNumber(
    firstMatch(text, [
      /temp(?:erature)?\s*[:\-]?\s*([\d.]+)\s*°?\s*[CF]?/i,
      /(\d{2,3}(?:\.\d+)?)\s*°\s*C/i,
    ]),
  );

  const pressure = parseNumber(
    firstMatch(text, [/pressure\s*[:\-]?\s*([\d.]+)\s*(?:bar|kpa|psi)?/i, /([\d.]+)\s*bar/i]),
  );

  const holdTimeSeconds = parseHoldTime(
    firstMatch(text, [
      /hold(?:ing)?\s*time\s*[:\-]?\s*(\d+\s*(?::\s*\d+|min|sec|s)?)/i,
      /sterili[sz]ation\s*time\s*[:\-]?\s*(\d+\s*(?::\s*\d+|min|sec|s)?)/i,
    ]),
  );

  const date = firstMatch(text, [
    /date\s*[:\-]?\s*(\d{1,4}[\/\-.]\d{1,2}[\/\-.]\d{1,4})/i,
    /(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4})/,
  ]);

  const time = firstMatch(text, [
    /time\s*[:\-]?\s*(\d{1,2}\s*:\s*\d{2}(?:\s*:\s*\d{2})?)/i,
    /(\d{1,2}:\d{2}(?::\d{2})?)/,
  ]);

  const machineIdentifier = firstMatch(text, [
    /(?:machine|unit|autoclave|sterilizer)\s*(?:id|no|number|#)?\s*[:\-]?\s*([A-Z0-9\-]+)/i,
    /serial\s*(?:no|number|#)?\s*[:\-]?\s*([A-Z0-9\-]+)/i,
  ]);

  const resultText = firstMatch(text, [/result\s*[:\-]?\s*(PASS|FAIL|ACCEPT|REJECT|OK|NG)/i]);

  return {
    cycle_number: cycleNumber,
    temperature,
    pressure,
    hold_time_seconds: holdTimeSeconds,
    date,
    time,
    machine_identifier: machineIdentifier,
    result: resultText ? resultText.toUpperCase() : null,
  };
}
