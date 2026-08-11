import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/user_model.dart';

void main() {
  group('UserModel.fromMap', () {
    test('parses required fields and defaults', () {
      final user = UserModel.fromMap({
        'email': 'driver@example.com',
        'fullName': 'أحمد السائق',
        'userType': 'driver',
        'phoneNumber': '079 123 4567',
        'isVerified': true,
      }, 'uid-1');

      expect(user.uid, 'uid-1');
      expect(user.email, 'driver@example.com');
      expect(user.fullName, 'أحمد السائق');
      expect(user.userType, 'driver');
      expect(user.phoneNumber, '0791234567');
      expect(user.isVerified, isTrue);
      expect(user.isRejected, isFalse);
    });

    test('defaults userType to passenger when missing', () {
      final user = UserModel.fromMap({
        'email': 'p@example.com',
        'fullName': 'راكب',
      }, 'uid-2');

      expect(user.userType, 'passenger');
      expect(user.isVerified, isFalse);
    });

    test('hasPhoto is true only when photoUrl is non-empty', () {
      final without = UserModel.fromMap({
        'email': 'a@b.com',
        'fullName': 'A',
      }, 'u1');
      final withPhoto = UserModel.fromMap({
        'email': 'a@b.com',
        'fullName': 'A',
        'photoUrl': 'https://example.com/p.jpg',
      }, 'u2');

      expect(without.hasPhoto, isFalse);
      expect(withPhoto.hasPhoto, isTrue);
    });
  });

  group('UserModel display helpers', () {
    test('displayUserType returns Arabic labels', () {
      expect(
        const UserModel(
          uid: '1',
          email: 'a@b.com',
          fullName: 'X',
          userType: 'admin',
        ).displayUserType,
        'مشرف',
      );
      expect(
        const UserModel(
          uid: '1',
          email: 'a@b.com',
          fullName: 'X',
          userType: 'driver',
        ).displayUserType,
        'سائق',
      );
      expect(
        const UserModel(
          uid: '1',
          email: 'a@b.com',
          fullName: 'X',
          userType: 'passenger',
        ).displayUserType,
        'راكب',
      );
    });

    test('displayName falls back when fullName is empty', () {
      const user = UserModel(
        uid: '1',
        email: 'a@b.com',
        fullName: '',
        userType: 'passenger',
      );
      expect(user.displayName, 'مستخدم');
    });

    test('copyWith updates selected fields only', () {
      const original = UserModel(
        uid: '1',
        email: 'a@b.com',
        fullName: 'Old',
        userType: 'driver',
        isVerified: false,
      );
      final updated = original.copyWith(
        fullName: 'New',
        isVerified: true,
      );

      expect(updated.fullName, 'New');
      expect(updated.isVerified, isTrue);
      expect(updated.email, original.email);
      expect(updated.userType, original.userType);
    });
  });
}
