/// ثوابت الخريطة المشتركة بين جميع الخرائط
class MapConstants {
  // ─── حدود الأردن (تُفرض على الكاميرا) ───────────────────────────
  // هوامش طفيفة حول الحدود الحقيقية لتقليل الارتداد عند الحافة
  static const double minLat = 28.95;
  static const double maxLat = 33.55;
  static const double minLng = 34.70;
  static const double maxLng = 39.45;

  // ─── مركز الأردن (عمّان) ──────────────────────────────────────────
  static const double centerLat = 31.9522;
  static const double centerLng = 35.9106;

  // ─── إعدادات الكاميرا ────────────────────────────────────────────
  /// مستوى التكبير الافتراضي لإظهار معظم الأردن بوضوح
  static const double defaultZoom = 7.2;

  /// حدود الزوم — max أقل قليلاً يقلل ضغط البلاطات والرجّة
  static const double minZoom = 6.0;
  static const double maxZoom = 17.5;

  static const double detailZoom = 15.5;
  static const double cityZoom = 12.5;
  static const double routeFocusZoom = 11.0;

  // ─── مظهر خطوط الباص (رفيع حتى لا يغطي تفاصيل الشوارع) ──────────
  /// لون افتراضي للمسار إن لم يُحدد في البيانات
  static const int defaultRouteColor = 0xFF0E9F5D;

  /// عرض الخط الملوّن (ذهاب/إياب)
  static const double routeLineWidth = 2.2;

  /// الحد الخارجي الأبيض الخفيف حول الخط
  static const double routeOutlineWidth = 3.4;

  static const double routeLineOpacity = 0.90;
  static const double routeOutlineOpacity = 0.22;

  static const int routeOutlineColor = 0xFFFFFFFF;
}
