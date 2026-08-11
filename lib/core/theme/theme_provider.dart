import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يدير وضع المظهر (فاتح / داكن) ويحفظ التفضيل محلياً.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLoaded => _loaded;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (stored == 'light') {
        _themeMode = ThemeMode.light;
      } else if (stored == 'system') {
        _themeMode = ThemeMode.system;
      }
    } catch (_) {
      // نبقى على الوضع الفاتح عند أي خطأ
    } finally {
      _loaded = true;
      _applySystemUi();
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    await setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _applySystemUi();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefsKey, value);
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setDarkMode(!isDarkMode);
  }

  void _applySystemUi() {
    final dark = isDarkMode;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: dark ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
    );
  }
}
