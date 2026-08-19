/// Mirrors the public.user_role enum in supabase/migrations. Keep in sync.
enum UserRole {
  systemAdmin,
  hospitalAdmin,
  cssdSupervisor,
  cssdTechnician,
  otNurse,
  infectionControl,
  auditor,
  biomedicalEngineer,
  qualityManager;

  static UserRole? fromDb(String value) {
    for (final role in UserRole.values) {
      if (role.dbValue == value) return role;
    }
    return null;
  }

  String get dbValue {
    switch (this) {
      case UserRole.systemAdmin:
        return 'SYSTEM_ADMIN';
      case UserRole.hospitalAdmin:
        return 'HOSPITAL_ADMIN';
      case UserRole.cssdSupervisor:
        return 'CSSD_SUPERVISOR';
      case UserRole.cssdTechnician:
        return 'CSSD_TECHNICIAN';
      case UserRole.otNurse:
        return 'OT_NURSE';
      case UserRole.infectionControl:
        return 'INFECTION_CONTROL';
      case UserRole.auditor:
        return 'AUDITOR';
      case UserRole.biomedicalEngineer:
        return 'BIOMEDICAL_ENGINEER';
      case UserRole.qualityManager:
        return 'QUALITY_MANAGER';
    }
  }
}

/// Mirrors the public.equipment_status enum.
enum EquipmentStatus {
  active,
  lockedOut,
  maintenance,
  decommissioned;

  static EquipmentStatus fromDb(String value) {
    return EquipmentStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => EquipmentStatus.active,
    );
  }

  String get dbValue {
    switch (this) {
      case EquipmentStatus.active:
        return 'ACTIVE';
      case EquipmentStatus.lockedOut:
        return 'LOCKED_OUT';
      case EquipmentStatus.maintenance:
        return 'MAINTENANCE';
      case EquipmentStatus.decommissioned:
        return 'DECOMMISSIONED';
    }
  }
}
