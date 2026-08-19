class ExtractedCycleFields {
  final String? cycleNumber;
  final double? temperature;
  final double? pressure;
  final int? holdTimeSeconds;
  final String? date;
  final String? time;
  final String? machineIdentifier;
  final String? result;

  const ExtractedCycleFields({
    this.cycleNumber,
    this.temperature,
    this.pressure,
    this.holdTimeSeconds,
    this.date,
    this.time,
    this.machineIdentifier,
    this.result,
  });

  factory ExtractedCycleFields.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ExtractedCycleFields();
    return ExtractedCycleFields(
      cycleNumber: json['cycle_number'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      holdTimeSeconds: (json['hold_time_seconds'] as num?)?.toInt(),
      date: json['date'] as String?,
      time: json['time'] as String?,
      machineIdentifier: json['machine_identifier'] as String?,
      result: json['result'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'cycle_number': cycleNumber,
        'temperature': temperature,
        'pressure': pressure,
        'hold_time_seconds': holdTimeSeconds,
        'date': date,
        'time': time,
        'machine_identifier': machineIdentifier,
        'result': result,
      };
}

class OcrExtraction {
  final String id;
  final String status;
  final String? rawText;
  final ExtractedCycleFields extractedFields;
  final ExtractedCycleFields? humanConfirmedFields;
  final String? errorMessage;
  final DateTime? confirmedAt;

  const OcrExtraction({
    required this.id,
    required this.status,
    required this.rawText,
    required this.extractedFields,
    required this.humanConfirmedFields,
    required this.errorMessage,
    required this.confirmedAt,
  });

  factory OcrExtraction.fromJson(Map<String, dynamic> json) {
    return OcrExtraction(
      id: json['id'] as String,
      status: json['status'] as String,
      rawText: json['raw_text'] as String?,
      extractedFields: ExtractedCycleFields.fromJson(json['extracted_fields'] as Map<String, dynamic>?),
      humanConfirmedFields: json['human_confirmed_fields'] != null
          ? ExtractedCycleFields.fromJson(json['human_confirmed_fields'] as Map<String, dynamic>)
          : null,
      errorMessage: json['error_message'] as String?,
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at'] as String) : null,
    );
  }
}
