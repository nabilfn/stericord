enum CycleStatus {
  created,
  running,
  completed,
  pendingVerification,
  passed,
  failed,
  quarantined;

  static CycleStatus fromDb(String value) {
    return CycleStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => CycleStatus.created,
    );
  }

  String get dbValue {
    switch (this) {
      case CycleStatus.created:
        return 'CREATED';
      case CycleStatus.running:
        return 'RUNNING';
      case CycleStatus.completed:
        return 'COMPLETED';
      case CycleStatus.pendingVerification:
        return 'PENDING_VERIFICATION';
      case CycleStatus.passed:
        return 'PASSED';
      case CycleStatus.failed:
        return 'FAILED';
      case CycleStatus.quarantined:
        return 'QUARANTINED';
    }
  }
}

enum VerificationResult {
  pass,
  fail,
  undetermined;

  String get dbValue {
    switch (this) {
      case VerificationResult.pass:
        return 'PASS';
      case VerificationResult.fail:
        return 'FAIL';
      case VerificationResult.undetermined:
        return 'UNDETERMINED';
    }
  }
}

class SterilizationCycle {
  final String id;
  final String organizationId;
  final String equipmentId;
  final String cycleNumber;
  final String cycleType;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? temperature;
  final double? pressure;
  final int? holdTimeSeconds;
  final CycleStatus cycleStatus;
  final DateTime createdAt;

  const SterilizationCycle({
    required this.id,
    required this.organizationId,
    required this.equipmentId,
    required this.cycleNumber,
    required this.cycleType,
    required this.startedAt,
    required this.completedAt,
    required this.temperature,
    required this.pressure,
    required this.holdTimeSeconds,
    required this.cycleStatus,
    required this.createdAt,
  });

  factory SterilizationCycle.fromJson(Map<String, dynamic> json) {
    return SterilizationCycle(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      equipmentId: json['equipment_id'] as String,
      cycleNumber: json['cycle_number'] as String,
      cycleType: json['cycle_type'] as String,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      temperature: (json['temperature'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      holdTimeSeconds: json['hold_time_seconds'] as int?,
      cycleStatus: CycleStatus.fromDb(json['cycle_status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
