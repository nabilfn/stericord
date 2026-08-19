import type { EvidenceType } from "@/types/database";

export type QualityStatus = "ACCEPTED" | "RETAKE_REQUIRED";
export type QualityReason = "IMAGE_TOO_BLURRY" | "IMAGE_TOO_DARK" | "GLARE_DETECTED" | "INDICATOR_NOT_IN_FRAME";

export interface ImageQualityResult {
  status: QualityStatus;
  reasons: QualityReason[];
  blurScore: number;
  brightnessScore: number;
  glareRatio: number;
}

interface QualityThresholds {
  /** Minimum variance of the Laplacian over a normalized-size grayscale image. Higher = sharper. */
  minBlurScore: number;
  minBrightness: number;
  maxGlareRatio: number;
}

/**
 * Per evidence-type thresholds -- master prompt section 33: "Do not rely on
 * one universal hard-coded blur threshold." A chemical indicator strip and
 * a printed thermal receipt don't have the same texture, so one constant
 * would be wrong for at least one of them. Tune these against real device
 * photos during pilot hardening (Phase 8); DEFAULT covers evidence types
 * without a specific entry.
 */
const THRESHOLDS: Record<EvidenceType | "DEFAULT", QualityThresholds> = {
  AUTOCLAVE_RECEIPT: { minBlurScore: 45, minBrightness: 55, maxGlareRatio: 0.12 },
  BOWIE_DICK: { minBlurScore: 35, minBrightness: 50, maxGlareRatio: 0.15 },
  BI_TRAY: { minBlurScore: 35, minBrightness: 50, maxGlareRatio: 0.15 },
  CHEMICAL_INDICATOR: { minBlurScore: 30, minBrightness: 45, maxGlareRatio: 0.18 },
  OT_INDICATOR: { minBlurScore: 30, minBrightness: 45, maxGlareRatio: 0.18 },
  WASHER_TEST: { minBlurScore: 35, minBrightness: 50, maxGlareRatio: 0.15 },
  GENERAL: { minBlurScore: 25, minBrightness: 40, maxGlareRatio: 0.2 },
  DEFAULT: { minBlurScore: 25, minBrightness: 40, maxGlareRatio: 0.2 },
};

const ANALYSIS_MAX_DIMENSION = 640;
const GLARE_LUMINANCE_THRESHOLD = 245;

function loadImage(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not decode image"));
    };
    img.src = url;
  });
}

function toGrayscale(imageData: ImageData): Float32Array {
  const { data, width, height } = imageData;
  const gray = new Float32Array(width * height);
  for (let i = 0, p = 0; i < data.length; i += 4, p++) {
    // Rec. 601 luma weights.
    gray[p] = 0.299 * data[i]! + 0.587 * data[i + 1]! + 0.114 * data[i + 2]!;
  }
  return gray;
}

/** Variance of the 3x3 Laplacian response -- the standard "how sharp is this image" measure. */
function laplacianVariance(gray: Float32Array, width: number, height: number): number {
  const responses: number[] = [];
  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      const i = y * width + x;
      const lap =
        4 * gray[i]! - gray[i - 1]! - gray[i + 1]! - gray[i - width]! - gray[i + width]!;
      responses.push(lap);
    }
  }
  const mean = responses.reduce((a, b) => a + b, 0) / responses.length;
  const variance = responses.reduce((a, b) => a + (b - mean) ** 2, 0) / responses.length;
  return variance;
}

export async function analyzeImageQuality(file: File, evidenceType: EvidenceType): Promise<ImageQualityResult> {
  const img = await loadImage(file);
  const scale = Math.min(1, ANALYSIS_MAX_DIMENSION / Math.max(img.width, img.height));
  const width = Math.max(1, Math.round(img.width * scale));
  const height = Math.max(1, Math.round(img.height * scale));

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas 2D context unavailable");
  ctx.drawImage(img, 0, 0, width, height);
  const imageData = ctx.getImageData(0, 0, width, height);

  const gray = toGrayscale(imageData);
  const blurScore = laplacianVariance(gray, width, height);
  const brightnessScore = gray.reduce((a, b) => a + b, 0) / gray.length;

  let glareCount = 0;
  for (let i = 0; i < gray.length; i++) {
    if (gray[i]! >= GLARE_LUMINANCE_THRESHOLD) glareCount++;
  }
  const glareRatio = glareCount / gray.length;

  const thresholds = THRESHOLDS[evidenceType] ?? THRESHOLDS.DEFAULT;
  const reasons: QualityReason[] = [];
  if (blurScore < thresholds.minBlurScore) reasons.push("IMAGE_TOO_BLURRY");
  if (brightnessScore < thresholds.minBrightness) reasons.push("IMAGE_TOO_DARK");
  if (glareRatio > thresholds.maxGlareRatio) reasons.push("GLARE_DETECTED");

  return {
    status: reasons.length === 0 ? "ACCEPTED" : "RETAKE_REQUIRED",
    reasons,
    blurScore,
    brightnessScore,
    glareRatio,
  };
}
