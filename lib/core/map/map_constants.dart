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

  // ─── مظهر خطوط الباص (أرفع حتى لا تغطي تفاصيل الشوارع) ─────────
  /// لون افتراضي للمسار إن لم يُحدد في البيانات
  static const int defaultRouteColor = 0xFF0E9F5D;

  /// عرض الخط الملوّن (ذهاب/إياب)
  static const double routeLineWidth = 3.0;

  /// الحد الخارجي الأبيض الخفيف حول الخط
  static const double routeOutlineWidth = 4.5;

  static const double routeLineOpacity = 0.92;
  static const double routeOutlineOpacity = 0.28;

  static const int routeOutlineColor = 0xFFFFFFFF;
}
