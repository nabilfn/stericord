# Phase 4 — Image Quality: architectural decisions

## Scope: three real checks, one honest limitation, one deferred

The master prompt (section 33) lists five things: blur, exposure, glare,
perspective correction, and framing assistance. This phase implements the
first three for real, using actual pixel math, not a placeholder:

- **Blur** — variance of the 3×3 Laplacian over a grayscale, resized copy
  of the image. This is the standard, well-established "how sharp is this"
  measure — a sharp image has high-frequency edges that produce a
  high-variance Laplacian response; a blurry one doesn't.
- **Exposure** — mean luminance (Rec. 601 weights) of the same grayscale
  data.
- **Glare** — fraction of pixels at or above a near-white luminance
  threshold (highlight clipping).

**Framing assistance** is implemented as a capture-time UX hint (a short
instruction shown next to the upload/capture control: "fill the frame,
avoid glare, hold steady"), not a pixel-classified `INDICATOR_NOT_IN_FRAME`
rejection. Detecting whether an indicator strip is actually present and
correctly framed requires object detection — recognizing *what* is in the
photo, not just measuring its pixel statistics. That's a genuinely
different capability than blur/exposure/glare, and it's also literally
what Phase 6 (Gemini multimodal AI) exists to do. Faking it with a shortcut
here (e.g., "reject if the image is mostly one color") would produce
false rejections on legitimate photos and false acceptances on badly
framed ones — worse than not checking at all. The `INDICATOR_NOT_IN_FRAME`
enum value exists (for schema forward-compatibility with Phase 6) but
nothing sets it yet.

**Perspective correction** (warping a skewed document photo to a top-down
view) is not implemented. It requires edge/contour detection and a
homography transform — real computer vision, not a few lines of pixel
math — and there's no native OpenCV available in a browser or in Flutter
without platform-specific bindings this environment can't compile-test.
Rather than ship a fake or broken version, it's left out and documented
here as deferred, not silently dropped.

## Where the check runs: client-side, before upload, in both apps

Both `apps/web/src/services/imageQuality.ts` and
`apps/mobile/lib/core/vision/image_quality.dart` implement the identical
algorithm independently (Canvas `ImageData` on web, the `image` package's
decoded pixel buffer on mobile) rather than routing through a server
round-trip. A blurry photo is caught and the user is asked to retake it
*before* any network request — no wasted upload bandwidth, no evidence
record for a rejected capture, and it works whether or not the device has
connectivity at the moment of capture (relevant groundwork for Phase 8's
offline queue).

The database only ever sees `quality_status = 'ACCEPTED'` in practice.
`RETAKE_REQUIRED` blocks the upload client-side, so no row is written for
it. The column still allows the value (defense in depth, and honest schema
design — the enum reflects the real state space even though one branch is
currently unreachable through the UI).

## No universal blur threshold

Per section 33's explicit instruction, thresholds are keyed by
`evidence_type`, not one constant. A chemical indicator strip and a printed
thermal receipt don't have comparable texture/contrast, so a single
"variance > 50" rule would be wrong for at least one of them. Both
`imageQuality.ts` and `image_quality.dart` carry the same
per-evidence-type threshold table; keep them in sync if you tune one.

Images are resized to a fixed 640px long edge before analysis. This isn't
just a performance optimization — Laplacian variance scales with pixel
density, so without normalizing to a consistent analysis resolution, the
same physical sharpness would score differently on a 12MP phone photo
than a 2MP one, making the thresholds meaningless across devices.

## Verified

Generated two real test JPEGs (not a fake/stub file) with Pillow: one
sharp/well-lit, one Gaussian-blurred and darkened. Uploaded both through
the actual web UI with a headless browser:

- The blurry/dark image was rejected with both `IMAGE_TOO_BLURRY` and
  `IMAGE_TOO_DARK` shown, and never appeared in the evidence list.
- The sharp image was accepted, appears in the evidence list, and its
  stored `blur_score`/`brightness_score`/`glare_ratio`/`quality_status`
  were confirmed correct directly in the database.
