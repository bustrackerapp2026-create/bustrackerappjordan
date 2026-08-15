/// ثوابت الخريطة المشتركة بين جميع الخرائط
class MapConstants {
  // ─── حدود الأردن (مرجعية فقط — لا تُفرض على الكاميرا) ───────────
  static const double minLat = 28.8;
  static const double maxLat = 33.6;
  static const double minLng = 34.5;
  static const double maxLng = 39.5;

  // ─── مركز الأردن (عمّان) ──────────────────────────────────────────
  static const double centerLat = 31.9522;
  static const double centerLng = 35.9106;

  // ─── إعدادات الكاميرا ────────────────────────────────────────────
  /// مستوى التكبير الافتراضي لإظهار معظم الأردن بوضوح
  static const double defaultZoom = 7.2;

  /// قيم مرجعية فقط لـ flyTo — لا تُفرض عبر setBounds
  static const double minZoom = 5.0;
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
