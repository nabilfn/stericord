import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum QualityStatus { accepted, retakeRequired }

enum QualityReason {
  imageTooBlurry,
  imageTooDark,
  glareDetected,
  indicatorNotInFrame;

  String get dbValue {
    switch (this) {
      case QualityReason.imageTooBlurry:
        return 'IMAGE_TOO_BLURRY';
      case QualityReason.imageTooDark:
        return 'IMAGE_TOO_DARK';
      case QualityReason.glareDetected:
        return 'GLARE_DETECTED';
      case QualityReason.indicatorNotInFrame:
        return 'INDICATOR_NOT_IN_FRAME';
    }
  }

  String get label {
    switch (this) {
      case QualityReason.imageTooBlurry:
        return 'Image is too blurry — hold steady and refocus.';
      case QualityReason.imageTooDark:
        return 'Image is too dark — retake with better lighting.';
      case QualityReason.glareDetected:
        return 'Glare detected — tilt to avoid reflections.';
      case QualityReason.indicatorNotInFrame:
        return 'Indicator not fully in frame.';
    }
  }
}

class ImageQualityResult {
  final QualityStatus status;
  final List<QualityReason> reasons;
  final double blurScore;
  final double brightnessScore;
  final double glareRatio;

  const ImageQualityResult({
    required this.status,
    required this.reasons,
    required this.blurScore,
    required this.brightnessScore,
    required this.glareRatio,
  });
}

class _QualityThresholds {
  final double minBlurScore;
  final double minBrightness;
  final double maxGlareRatio;
  const _QualityThresholds({
    required this.minBlurScore,
    required this.minBrightness,
    required this.maxGlareRatio,
  });
}

/// Per evidence-type thresholds -- see apps/web/src/services/imageQuality.ts
/// for the matching web-side config and the rationale (master prompt
/// section 33: no single universal blur threshold).
const Map<String, _QualityThresholds> _thresholds = {
  'AUTOCLAVE_RECEIPT': _QualityThresholds(minBlurScore: 45, minBrightness: 55, maxGlareRatio: 0.12),
  'BOWIE_DICK': _QualityThresholds(minBlurScore: 35, minBrightness: 50, maxGlareRatio: 0.15),
  'BI_TRAY': _QualityThresholds(minBlurScore: 35, minBrightness: 50, maxGlareRatio: 0.15),
  'CHEMICAL_INDICATOR': _QualityThresholds(minBlurScore: 30, minBrightness: 45, maxGlareRatio: 0.18),
  'OT_INDICATOR': _QualityThresholds(minBlurScore: 30, minBrightness: 45, maxGlareRatio: 0.18),
  'WASHER_TEST': _QualityThresholds(minBlurScore: 35, minBrightness: 50, maxGlareRatio: 0.15),
  'GENERAL': _QualityThresholds(minBlurScore: 25, minBrightness: 40, maxGlareRatio: 0.2),
};
const _defaultThresholds = _QualityThresholds(minBlurScore: 25, minBrightness: 40, maxGlareRatio: 0.2);

const _analysisMaxDimension = 640;
const _glareLuminanceThreshold = 245.0;

/// Analyzes a captured photo for blur, exposure, and glare before it is
/// uploaded as evidence. Returns null if the bytes can't be decoded as an
/// image (caller should upload without a quality score in that case rather
/// than block on an analysis bug).
ImageQualityResult? analyzeImageQuality(Uint8List bytes, String evidenceType) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final longEdge = decoded.width > decoded.height ? decoded.width : decoded.height;
  final scale = _analysisMaxDimension / longEdge;
  final resized = scale < 1
      ? img.copyResize(decoded, width: (decoded.width * scale).round(), height: (decoded.height * scale).round())
      : decoded;

  final width = resized.width;
  final height = resized.height;
  final gray = List<double>.filled(width * height, 0);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = resized.getPixel(x, y);
      gray[y * width + x] = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
    }
  }

  final blurScore = _laplacianVariance(gray, width, height);
  final brightnessScore = gray.reduce((a, b) => a + b) / gray.length;

  var glareCount = 0;
  for (final v in gray) {
    if (v >= _glareLuminanceThreshold) glareCount++;
  }
  final glareRatio = glareCount / gray.length;

  final thresholds = _thresholds[evidenceType] ?? _defaultThresholds;
  final reasons = <QualityReason>[];
  if (blurScore < thresholds.minBlurScore) reasons.add(QualityReason.imageTooBlurry);
  if (brightnessScore < thresholds.minBrightness) reasons.add(QualityReason.imageTooDark);
  if (glareRatio > thresholds.maxGlareRatio) reasons.add(QualityReason.glareDetected);

  return ImageQualityResult(
    status: reasons.isEmpty ? QualityStatus.accepted : QualityStatus.retakeRequired,
    reasons: reasons,
    blurScore: blurScore,
    brightnessScore: brightnessScore,
    glareRatio: glareRatio,
  );
}

double _laplacianVariance(List<double> gray, int width, int height) {
  final responses = <double>[];
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final i = y * width + x;
      final lap = 4 * gray[i] - gray[i - 1] - gray[i + 1] - gray[i - width] - gray[i + width];
      responses.add(lap);
    }
  }
  if (responses.isEmpty) return 0;
  final mean = responses.reduce((a, b) => a + b) / responses.length;
  final variance = responses.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) / responses.length;
  return variance;
}
