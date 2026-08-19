enum IncidentStatus {
  detected,
  alerted,
  acknowledged,
  replacementDispatched,
  replacementReceived,
  quarantineInProgress,
  ncrOpen,
  resolved,
  closed;

  static IncidentStatus fromDb(String value) {
    return IncidentStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => IncidentStatus.detected,
    );
  }

  String get dbValue {
    switch (this) {
      case IncidentStatus.detected:
        return 'DETECTED';
      case IncidentStatus.alerted:
        return 'ALERTED';
      case IncidentStatus.acknowledged:
        return 'ACKNOWLEDGED';
      case IncidentStatus.replacementDispatched:
        return 'REPLACEMENT_DISPATCHED';
      case IncidentStatus.replacementReceived:
        return 'REPLACEMENT_RECEIVED';
      case IncidentStatus.quarantineInProgress:
        return 'QUARANTINE_IN_PROGRESS';
      case IncidentStatus.ncrOpen:
        return 'NCR_OPEN';
      case IncidentStatus.resolved:
        return 'RESOLVED';
      case IncidentStatus.closed:
        return 'CLOSED';
    }
  }
}

class Incident {
  final String id;
  final String sourceType;
  final String? description;
  final IncidentStatus status;
  final String priority;
  final DateTime detectedAt;
  final String? resolutionNotes;

  const Incident({
    required this.id,
    required this.sourceType,
    required this.description,
    required this.status,
    required this.priority,
    required this.detectedAt,
    required this.resolutionNotes,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      sourceType: json['source_type'] as String,
      description: json['description'] as String?,
      status: IncidentStatus.fromDb(json['status'] as String),
      priority: json['priority'] as String,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }
}
