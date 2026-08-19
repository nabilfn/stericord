class AiAnalysis {
  final String id;
  final String status;
  final String? suggestedResult;
  final double? confidence;
  final String? confidenceBand;
  final List<String> observations;
  final String? errorMessage;

  const AiAnalysis({
    required this.id,
    required this.status,
    required this.suggestedResult,
    required this.confidence,
    required this.confidenceBand,
    required this.observations,
    required this.errorMessage,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    return AiAnalysis(
      id: json['id'] as String,
      status: json['status'] as String,
      suggestedResult: json['suggested_result'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      confidenceBand: json['confidence_band'] as String?,
      observations: (json['observations'] as List?)?.map((e) => e.toString()).toList() ?? [],
      errorMessage: json['error_message'] as String?,
    );
  }
}
