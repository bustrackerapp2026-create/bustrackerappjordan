import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/core/constants/user_roles.dart';

void main() {
  group('UserRoles constants', () {
    test('exposes expected role string constants', () {
      expect(UserRoles.admin, 'admin');
      expect(UserRoles.driver, 'driver');
      expect(UserRoles.passenger, 'passenger');
      expect(UserRoles.service, 'service');
      expect(UserRoles.busCompany, 'bus_company');
    });

    test('all contains every known role exactly once', () {
      expect(UserRoles.all.toSet().length, UserRoles.all.length);
      expect(
        UserRoles.all,
        containsAll([
          UserRoles.admin,
          UserRoles.driver,
          UserRoles.passenger,
          UserRoles.service,
          UserRoles.busCompany,
        ]),
      );
    });
  });

  group('UserRoles helpers', () {
    test('isKnown', () {
      expect(UserRoles.isKnown('driver'), isTrue);
      expect(UserRoles.isKnown('bus_company'), isTrue);
      expect(UserRoles.isKnown('unknown'), isFalse);
      expect(UserRoles.isKnown(null), isFalse);
    });

    test('isDriverLike and needsVerification', () {
      expect(UserRoles.isDriverLike(UserRoles.driver), isTrue);
      expect(UserRoles.isDriverLike(UserRoles.service), isTrue);
      expect(UserRoles.isDriverLike(UserRoles.busCompany), isTrue);
      expect(UserRoles.isDriverLike(UserRoles.passenger), isFalse);
      expect(UserRoles.isDriverLike(UserRoles.admin), isFalse);

      expect(UserRoles.needsVerification(UserRoles.driver), isTrue);
      expect(UserRoles.needsVerification(UserRoles.passenger), isFalse);
    });

    test('canSelfRegister excludes admin', () {
      expect(UserRoles.canSelfRegister(UserRoles.passenger), isTrue);
      expect(UserRoles.canSelfRegister(UserRoles.driver), isTrue);
      expect(UserRoles.canSelfRegister(UserRoles.admin), isFalse);
    });

    test('displayLabelAr returns Arabic labels', () {
      expect(UserRoles.displayLabelAr(UserRoles.admin), 'مشرف');
      expect(UserRoles.displayLabelAr(UserRoles.driver), 'سائق');
      expect(UserRoles.displayLabelAr(UserRoles.passenger), 'راكب');
      expect(UserRoles.displayLabelAr(UserRoles.service), 'سرفيس');
      expect(UserRoles.displayLabelAr(UserRoles.busCompany), 'باص شركة');
      expect(UserRoles.displayLabelAr(null), 'غير محدد');
    });
  });
}
