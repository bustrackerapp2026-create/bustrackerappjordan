/// ثوابت الخريطة المشتركة بين جميع الخرائط
class MapConstants {
  // ─── حدود الأردن (تُفرض على الكاميرا) ───────────────────────────
  static const double minLat = 29.1;
  static const double maxLat = 33.45;
  static const double minLng = 34.85;
  static const double maxLng = 39.35;

  // ─── مركز الأردن (عمّان) ──────────────────────────────────────────
  static const double centerLat = 31.9522;
  static const double centerLng = 35.9106;

  // ─── إعدادات الكاميرا ────────────────────────────────────────────
  /// مستوى التكبير الافتراضي لإظهار معظم الأردن بوضوح
  static const double defaultZoom = 7.2;

  /// حدود الزوم داخل الأردن
  static const double minZoom = 5.8;
  static const double maxZoom = 18.5;

  static const double detailZoom = 15.5;
  static const double cityZoom = 12.5;
  static const double routeFocusZoom = 11.0;

  // ─── مظهر خطوط الباص (مثل تطبيقات المواصلات) ───────────────────
  /// لون افتراضي للمسار إن لم يُحدد في البيانات
  static const int defaultRouteColor = 0xFF0E9F5D;

  static const double routeLineWidth = 5.5;
  static const double routeOutlineWidth = 8.0;
  static const double routeLineOpacity = 0.95;
  static const double routeOutlineOpacity = 0.35;

  static const int routeOutlineColor = 0xFFFFFFFF;
}
