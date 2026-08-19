enum PackStatus {
  packed,
  sterilizing,
  pendingVerification,
  released,
  quarantined,
  recalled,
  used,
  expired;

  static PackStatus fromDb(String value) {
    return PackStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => PackStatus.packed,
    );
  }

  String get dbValue {
    switch (this) {
      case PackStatus.packed:
        return 'PACKED';
      case PackStatus.sterilizing:
        return 'STERILIZING';
      case PackStatus.pendingVerification:
        return 'PENDING_VERIFICATION';
      case PackStatus.released:
        return 'RELEASED';
      case PackStatus.quarantined:
        return 'QUARANTINED';
      case PackStatus.recalled:
        return 'RECALLED';
      case PackStatus.used:
        return 'USED';
      case PackStatus.expired:
        return 'EXPIRED';
    }
  }
}

class InstrumentSet {
  final String id;
  final String name;
  final String code;

  const InstrumentSet({required this.id, required this.name, required this.code});

  factory InstrumentSet.fromJson(Map<String, dynamic> json) {
    return InstrumentSet(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }
}

class InstrumentPack {
  final String id;
  final String organizationId;
  final String instrumentSetId;
  final String sterilizationCycleId;
  final String packCode;
  final String qrCode;
  final DateTime packedAt;
  final DateTime? sterilizedAt;
  final DateTime? expiryDate;
  final PackStatus status;

  const InstrumentPack({
    required this.id,
    required this.organizationId,
    required this.instrumentSetId,
    required this.sterilizationCycleId,
    required this.packCode,
    required this.qrCode,
    required this.packedAt,
    required this.sterilizedAt,
    required this.expiryDate,
    required this.status,
  });

  factory InstrumentPack.fromJson(Map<String, dynamic> json) {
    return InstrumentPack(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      instrumentSetId: json['instrument_set_id'] as String,
      sterilizationCycleId: json['sterilization_cycle_id'] as String,
      packCode: json['pack_code'] as String,
      qrCode: json['qr_code'] as String,
      packedAt: DateTime.parse(json['packed_at'] as String),
      sterilizedAt: json['sterilized_at'] != null ? DateTime.parse(json['sterilized_at'] as String) : null,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date'] as String) : null,
      status: PackStatus.fromDb(json['status'] as String),
    );
  }
}
