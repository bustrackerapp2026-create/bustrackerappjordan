/// ثوابت الخريطة المشتركة بين جميع الخرائط
class MapConstants {
  // ─── حدود الأردن ──────────────────────────────────────────────────
  /// الحد الأدنى لخط العرض (جنوب الأردن)
  static const double minLat = 29.1;

  /// الحد الأقصى لخط العرض (شمال الأردن)
  static const double maxLat = 33.4;

  /// الحد الأدنى لخط الطول (غرب الأردن)
  static const double minLng = 34.8;

  /// الحد الأقصى لخط الطول (شرق الأردن)
  static const double maxLng = 39.2;

  // ─── مركز الأردن (عمان) ──────────────────────────────────────────
  /// خط عرض وسط عمان
  static const double centerLat = 31.9522;

  /// خط طول وسط عمان
  static const double centerLng = 35.9106;

  // ─── إعدادات الكاميرا الافتراضية ──────────────────────────────
  /// مستوى التكبير لإظهار الأردن كاملاً
  static const double defaultZoom = 8.5;

  /// مستوى التكبير للتفاصيل (عند تحديد موقع معين)
  static const double detailZoom = 15.0;

  /// مستوى التكبير عند عرض مدينة معينة
  static const double cityZoom = 12.0;
}
