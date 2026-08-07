import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/core/utils/validators.dart';

void main() {
  group('AppValidators', () {
    test('validates required fields', () {
      expect(AppValidators.validateRequired('', fieldName: 'الاسم'),
          'الرجاء إدخال الاسم');
      expect(AppValidators.validateRequired('أحمد', fieldName: 'الاسم'), isNull);
    });

    test('validates email format', () {
      expect(AppValidators.validateEmail('test@example.com'), isNull);
      expect(AppValidators.validateEmail('invalid-email'),
          'صيغة البريد الإلكتروني غير صحيحة');
    });

    test('validates password length', () {
      expect(AppValidators.validatePassword('123456'), isNull);
      expect(AppValidators.validatePassword('12345'),
          'كلمة السر يجب أن تكون 6 أحرف على الأقل');
    });

    test('sanitizes email', () {
      expect(AppValidators.sanitizeEmail('  Test@Example.COM '),
          'test@example.com');
    });
  });
}
