import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/core/constants/user_roles.dart';

void main() {
  group('UserRoles', () {
    test('exposes expected role string constants', () {
      expect(UserRoles.admin, 'admin');
      expect(UserRoles.driver, 'driver');
      expect(UserRoles.passenger, 'passenger');
    });
  });
}
