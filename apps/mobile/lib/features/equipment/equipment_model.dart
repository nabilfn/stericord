import 'package:stericord_mobile/core/constants/roles.dart';

class Equipment {
  final String id;
  final String organizationId;
  final String equipmentCode;
  final String equipmentType;
  final String? manufacturer;
  final String? modelName;
  final String? serialNumber;
  final String? location;
  final EquipmentStatus operatingStatus;

  const Equipment({
    required this.id,
    required this.organizationId,
    required this.equipmentCode,
    required this.equipmentType,
    required this.manufacturer,
    required this.modelName,
    required this.serialNumber,
    required this.location,
    required this.operatingStatus,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      equipmentCode: json['equipment_code'] as String,
      equipmentType: json['equipment_type'] as String,
      manufacturer: json['manufacturer'] as String?,
      modelName: json['model_name'] as String?,
      serialNumber: json['serial_number'] as String?,
      location: json['location'] as String?,
      operatingStatus: EquipmentStatus.fromDb(json['operating_status'] as String),
    );
  }
}

class EquipmentStatusEvent {
  final String id;
  final String? previousStatus;
  final String newStatus;
  final DateTime changedAt;

  const EquipmentStatusEvent({
    required this.id,
    required this.previousStatus,
    required this.newStatus,
    required this.changedAt,
  });

  factory EquipmentStatusEvent.fromJson(Map<String, dynamic> json) {
    return EquipmentStatusEvent(
      id: json['id'] as String,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String,
      changedAt: DateTime.parse(json['changed_at'] as String),
    );
  }
}
