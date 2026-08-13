import 'dart:math' as math;

/// حساب المسافة وETA التقريبي لتجربة الراكب.
class EtaUtils {
  EtaUtils._();

  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double d) => d * math.pi / 180;

  /// تقدير دقائق الوصول.
  /// [speedMps] سرعة السائق م/ث إن توفرت، وإلا سرعة حضرية افتراضية.
  static int estimateMinutes({
    required double distanceMeters,
    double? speedMps,
  }) {
    if (distanceMeters <= 40) return 0;

    // سرعة افتراضية داخل المدن الأردنية ~22 كم/س ≈ 6.1 م/ث
    var speed = (speedMps != null && speedMps.isFinite && speedMps > 1.5)
        ? speedMps
        : 6.1;

    // لا نبالغ في السرعة العالية على تقدير الوصول
    if (speed > 16) speed = 16;

    final seconds = distanceMeters / speed;
    // هامش ازدحام خفيف
    final withBuffer = seconds * 1.15;
    final mins = (withBuffer / 60).ceil();
    return mins.clamp(1, 180);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} م';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  static String formatEta(int minutes) {
    if (minutes <= 0) return 'وصل تقريباً';
    if (minutes == 1) return 'خلال دقيقة';
    if (minutes < 60) return 'خلال $minutes د';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return 'خلال $h س';
    return 'خلال $h س و $m د';
  }

  static String approachingMessage(int minutes) {
    if (minutes <= 0) return 'الباص وصل قرب موقعك';
    if (minutes == 1) return 'الباص اقترب (دقيقة واحدة)';
    return 'الباص اقترب ($minutes دقائق)';
  }
}
