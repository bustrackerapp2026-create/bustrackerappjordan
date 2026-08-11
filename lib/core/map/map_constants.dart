/// ثوابت الخريطة المشتركة بين جميع الخرائط
class MapConstants {
  // ─── حدود الأردن (مرجعية فقط — لا تُفرض على الكاميرا) ───────────
  static const double minLat = 28.8;
  static const double maxLat = 33.6;
  static const double minLng = 34.5;
  static const double maxLng = 39.5;

  // ─── مركز الأردن (عمان) ──────────────────────────────────────────
  static const double centerLat = 31.9522;
  static const double centerLng = 35.9106;

  // ─── إعدادات الكاميرا ────────────────────────────────────────────
  /// مستوى التكبير الافتراضي لإظهار الأردن
  static const double defaultZoom = 7.5;

  /// قيم مرجعية فقط لـ flyTo — لا تُفرض عبر setBounds (كانت تسبب رجّة)
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;

  static const double detailZoom = 15.0;
  static const double cityZoom = 12.0;
}
