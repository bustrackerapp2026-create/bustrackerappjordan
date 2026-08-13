import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// يحفظ آخر خط اختاره الراكب ليفتحه تلقائياً في المرة التالية.
class RoutePrefsService {
  RoutePrefsService._();
  static final RoutePrefsService instance = RoutePrefsService._();
  factory RoutePrefsService() => instance;

  static const _key = 'passenger_preferred_route';

  Future<String> loadPreferredRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key)?.trim();
      if (saved != null &&
          saved.isNotEmpty &&
          AppConstants.jordanRoutes.contains(saved)) {
        return saved;
      }
    } catch (_) {}
    return AppConstants.jordanRoutes.first;
  }

  Future<void> savePreferredRoute(String route) async {
    final value = route.trim();
    if (value.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value);
    } catch (_) {}
  }
}
