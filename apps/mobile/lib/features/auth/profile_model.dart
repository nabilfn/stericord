class Profile {
  final String id;
  final String organizationId;
  final String? departmentId;
  final String fullName;
  final String email;
  final bool isActive;

  const Profile({
    required this.id,
    required this.organizationId,
    required this.departmentId,
    required this.fullName,
    required this.email,
    required this.isActive,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      departmentId: json['department_id'] as String?,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      isActive: json['is_active'] as bool,
    );
  }

  /// Used only for the offline profile cache (see AuthRepository) -- not a
  /// server payload shape, just a local round-trip of the same fields.
  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'department_id': departmentId,
        'full_name': fullName,
        'email': email,
        'is_active': isActive,
      };
}
