import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// تفضيلات خط الراكب + حالة شاشة أول مرة.
class RoutePrefsService {
  RoutePrefsService._();
  static final RoutePrefsService instance = RoutePrefsService._();
  factory RoutePrefsService() => instance;

  static const _keyRoute = 'passenger_preferred_route';
  static const _keyOnboardingDone = 'passenger_onboarding_done';

  /// هل أنهى شاشة أول مرة (حفظ أو تخطي)؟
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingDone) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingDone, true);
    } catch (_) {}
  }

  /// الخط المحفوظ أو null إن لم يختر بعد.
  Future<String?> loadPreferredRouteOrNull() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyRoute)?.trim();
      if (saved != null &&
          saved.isNotEmpty &&
          AppConstants.jordanRoutes.contains(saved)) {
        return saved;
      }
    } catch (_) {}
    return null;
  }

  /// للتوافق مع الكود القديم: يعيد خطاً محفوظاً أو أول خط كافتراضي للعرض.
  Future<String> loadPreferredRoute() async {
    return (await loadPreferredRouteOrNull()) ??
        AppConstants.jordanRoutes.first;
  }

  Future<void> savePreferredRoute(String route) async {
    final value = route.trim();
    if (value.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRoute, value);
      await prefs.setBool(_keyOnboardingDone, true);
    } catch (_) {}
  }

  /// تخطي أول مرة بدون حفظ خط.
  Future<void> skipOnboarding() async {
    await markOnboardingCompleted();
  }

  Future<void> clearPreferredRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRoute);
    } catch (_) {}
  }
}
