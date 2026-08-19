enum EvidenceType {
  autoclaveReceipt,
  bowieDick,
  biTray,
  chemicalIndicator,
  otIndicator,
  washerTest,
  general;

  String get dbValue {
    switch (this) {
      case EvidenceType.autoclaveReceipt:
        return 'AUTOCLAVE_RECEIPT';
      case EvidenceType.bowieDick:
        return 'BOWIE_DICK';
      case EvidenceType.biTray:
        return 'BI_TRAY';
      case EvidenceType.chemicalIndicator:
        return 'CHEMICAL_INDICATOR';
      case EvidenceType.otIndicator:
        return 'OT_INDICATOR';
      case EvidenceType.washerTest:
        return 'WASHER_TEST';
      case EvidenceType.general:
        return 'GENERAL';
    }
  }

  String get label => dbValue.replaceAll('_', ' ');
}

class EvidenceFile {
  final String id;
  final String entityType;
  final String entityId;
  final String bucket;
  final String objectPath;
  final EvidenceType evidenceType;
  final DateTime capturedAt;

  const EvidenceFile({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.bucket,
    required this.objectPath,
    required this.evidenceType,
    required this.capturedAt,
  });

  factory EvidenceFile.fromJson(Map<String, dynamic> json) {
    return EvidenceFile(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      bucket: json['bucket'] as String,
      objectPath: json['object_path'] as String,
      evidenceType: EvidenceType.values.firstWhere(
        (t) => t.dbValue == json['evidence_type'],
        orElse: () => EvidenceType.general,
      ),
      capturedAt: DateTime.parse(json['captured_at'] as String),
    );
  }
}
