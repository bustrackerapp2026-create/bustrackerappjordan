/// ثوابت الخريطة المشتركة بين جميع الخرائط
class MapConstants {
  // ─── حدود الأردن (مع هامش بسيط لتقليل صراع الحدود مع التكبير) ───
  static const double minLat = 28.8;
  static const double maxLat = 33.6;
  static const double minLng = 34.5;
  static const double maxLng = 39.5;

  // ─── مركز الأردن (عمان) ──────────────────────────────────────────
  static const double centerLat = 31.9522;
  static const double centerLng = 35.9106;

  // ─── إعدادات الكاميرا ────────────────────────────────────────────
  /// مستوى التكبير الافتراضي لإظهار الأردن
  static const double defaultZoom = 7.8;

  /// أقل تكبير مسموح (يمنع القفز عند التصغير الزائد)
  static const double minZoom = 6.0;

  /// أعلى تكبير مسموح
  static const double maxZoom = 18.5;

  static const double detailZoom = 15.0;
  static const double cityZoom = 12.0;
}
