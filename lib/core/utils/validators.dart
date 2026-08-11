import '../locale/locale_provider.dart';

class AppValidators {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  static final RegExp _phoneRegex = RegExp(
    r'^(?:\+962|962|0)?[789]\d{7,8}$',
  );

  static bool get _ar => LocaleProvider.languageCode != 'en';

  static String _t(String ar, String en) => _ar ? ar : en;

  static String? validateRequired(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return _t('الرجاء إدخال $fieldName', 'Please enter $fieldName');
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final trimmedValue = value?.trim() ?? '';
    if (trimmedValue.isEmpty) {
      return _t('الرجاء إدخال البريد الإلكتروني', 'Please enter email');
    }
    if (!_emailRegex.hasMatch(trimmedValue)) {
      return _t('صيغة البريد الإلكتروني غير صحيحة', 'Invalid email format');
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _t('الرجاء إدخال كلمة السر', 'Please enter password');
    }
    if (value.length < 6) {
      return _t(
        'كلمة السر يجب أن تكون 6 أحرف على الأقل',
        'Password must be at least 6 characters',
      );
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmedValue = value.trim();
    if (!_phoneRegex.hasMatch(trimmedValue)) {
      return _t('صيغة رقم الهاتف غير صحيحة', 'Invalid phone number format');
    }
    return null;
  }

  static String sanitizeEmail(String? value) {
    return (value ?? '').trim().toLowerCase();
  }
}
