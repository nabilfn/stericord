import 'package:flutter_test/flutter_test.dart';
import 'package:stericord_mobile/core/constants/roles.dart';

void main() {
  test('UserRole db value round-trips', () {
    for (final role in UserRole.values) {
      expect(UserRole.fromDb(role.dbValue), role);
    }
  });

  test('EquipmentStatus db value round-trips', () {
    for (final status in EquipmentStatus.values) {
      expect(EquipmentStatus.fromDb(status.dbValue), status);
    }
  });
}
