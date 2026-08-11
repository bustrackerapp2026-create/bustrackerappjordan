import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يدير لغة التطبيق (عربي / إنجليزي) ويحفظ التفضيل محلياً.
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_locale';

  /// يُحدَّث مع كل تغيير لغة — للاستخدام في Validators بلا context.
  static String languageCode = 'ar';

  Locale _locale = const Locale('ar');
  bool _loaded = false;

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isEnglish => _locale.languageCode == 'en';
  bool get isLoaded => _loaded;

  String get displayName => isArabic ? 'العربية' : 'English';

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code == 'en') {
        _locale = const Locale('en');
      } else if (code == 'ar') {
        _locale = const Locale('ar');
      }
      languageCode = _locale.languageCode;
    } catch (_) {
      // العربية افتراضياً
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    languageCode = locale.languageCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.languageCode);
    } catch (_) {}
  }

  Future<void> setArabic() => setLocale(const Locale('ar'));

  Future<void> setEnglish() => setLocale(const Locale('en'));

  Future<void> toggle() async {
    if (isArabic) {
      await setEnglish();
    } else {
      await setArabic();
    }
  }
}
