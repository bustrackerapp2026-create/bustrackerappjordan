import 'dart:math' as math;

/// نقطة موقع مع سرعة واتجاه وثقة.
class PredictedLocation {
  final double latitude;
  final double longitude;
  final double speedMs;
  final double headingDeg;
  final double confidence; // 0..1
  final DateTime timestamp;
  final bool isPredicted;

  const PredictedLocation({
    required this.latitude,
    required this.longitude,
    required this.speedMs,
    required this.headingDeg,
    required this.confidence,
    required this.timestamp,
    required this.isPredicted,
  });
}

/// خوارزمية تنبؤ موقع خفيفة للموبايل:
/// 1) تنعيم (EMA) للإحداثيات والسرعة والاتجاه
/// 2) dead reckoning بين قراءات GPS المتباعدة
/// 3) تخفيف الثقة مع الزمن ومنع القفزات غير المنطقية
///
/// مناسبة لتتبع باص/سائق بعد تخفيض معدل GPS لتوفير البطارية.
class LocationPredictor {
  double? _lat;
  double? _lng;
  double _speedMs = 0;
  double _headingDeg = 0;
  DateTime? _lastUpdate;
  double _confidence = 0;

  /// أقصى زمن للتنبؤ قبل التوقف (ثوانٍ)
  final double maxPredictSeconds;

  /// معامل تنعيم الموقع (أعلى = أقرب للقراءة الجديدة)
  final double positionAlpha;

  /// معامل تنعيم السرعة
  final double speedAlpha;

  /// أقصى قفزة مقبولة بين قراءتين (متر) — فوقها نثق بالقراءة الجديدة مباشرة
  final double maxJumpMeters;

  LocationPredictor({
    this.maxPredictSeconds = 8.0,
    this.positionAlpha = 0.35,
    this.speedAlpha = 0.4,
    this.maxJumpMeters = 120,
  });

  bool get hasState => _lat != null && _lng != null;

  /// تغذية بخيار GPS حقيقي
  PredictedLocation update({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? speedMs,
    double? headingDeg,
    double? accuracyMeters,
  }) {
    if (_lat == null || _lng == null || _lastUpdate == null) {
      _lat = latitude;
      _lng = longitude;
      _speedMs = (speedMs ?? 0).clamp(0, 40);
      _headingDeg = _normalizeHeading(headingDeg ?? 0);
      _lastUpdate = timestamp;
      _confidence = _confidenceFromAccuracy(accuracyMeters);
      return PredictedLocation(
        latitude: _lat!,
        longitude: _lng!,
        speedMs: _speedMs,
        headingDeg: _headingDeg,
        confidence: _confidence,
        timestamp: timestamp,
        isPredicted: false,
      );
    }

    final dt = timestamp.difference(_lastUpdate!).inMilliseconds / 1000.0;
    if (dt <= 0) {
      return PredictedLocation(
        latitude: _lat!,
        longitude: _lng!,
        speedMs: _speedMs,
        headingDeg: _headingDeg,
        confidence: _confidence,
        timestamp: timestamp,
        isPredicted: false,
      );
    }

    final jump = _distanceMeters(_lat!, _lng!, latitude, longitude);

    // قفزة كبيرة (نفق/تصحيح GPS): إعادة تهيئة جزئية
    if (jump > maxJumpMeters) {
      _lat = latitude;
      _lng = longitude;
      if (speedMs != null && speedMs >= 0) {
        _speedMs = speedMs.clamp(0, 40);
      }
      if (headingDeg != null) {
        _headingDeg = _normalizeHeading(headingDeg);
      }
      _lastUpdate = timestamp;
      _confidence = 0.55;
      return PredictedLocation(
        latitude: _lat!,
        longitude: _lng!,
        speedMs: _speedMs,
        headingDeg: _headingDeg,
        confidence: _confidence,
        timestamp: timestamp,
        isPredicted: false,
      );
    }

    // سرعة مشتقة من الإزاحة إن لم تُمرَّر
    final derivedSpeed = jump / dt;
    final measuredSpeed = (speedMs != null && speedMs > 0.3)
        ? speedMs
        : derivedSpeed;
    _speedMs =
        _lerp(_speedMs, measuredSpeed.clamp(0, 40), speedAlpha);

    // اتجاه: من الجهاز أو من متجه الحركة
    if (headingDeg != null && (speedMs == null || speedMs > 0.8)) {
      _headingDeg = _lerpHeading(_headingDeg, headingDeg, 0.45);
    } else if (jump > 2.0) {
      final movedHeading = _bearingDegrees(_lat!, _lng!, latitude, longitude);
      _headingDeg = _lerpHeading(_headingDeg, movedHeading, 0.5);
    }

    // تنعيم الموقع (EMA) — يعطي مساراً أقل اهتزازاً
    final alpha = _adaptiveAlpha(accuracyMeters, jump, dt);
    _lat = _lerp(_lat!, latitude, alpha);
    _lng = _lerp(_lng!, longitude, alpha);
    _lastUpdate = timestamp;
    _confidence = _confidenceFromAccuracy(accuracyMeters);

    return PredictedLocation(
      latitude: _lat!,
      longitude: _lng!,
      speedMs: _speedMs,
      headingDeg: _headingDeg,
      confidence: _confidence,
      timestamp: timestamp,
      isPredicted: false,
    );
  }

  /// تنبؤ للمستقبل من آخر حالة (بين قراءات GPS)
  PredictedLocation? predictAt(DateTime now) {
    if (_lat == null || _lng == null || _lastUpdate == null) return null;

    final dt = now.difference(_lastUpdate!).inMilliseconds / 1000.0;
    if (dt <= 0) {
      return PredictedLocation(
        latitude: _lat!,
        longitude: _lng!,
        speedMs: _speedMs,
        headingDeg: _headingDeg,
        confidence: _confidence,
        timestamp: now,
        isPredicted: false,
      );
    }

    if (dt > maxPredictSeconds || _speedMs < 0.4) {
      // توقف أو انتهاء نافذة التنبؤ — أعد آخر موضع معروف بثقة منخفضة
      final decay = math.max(0.0, 1.0 - (dt / (maxPredictSeconds * 1.5)));
      return PredictedLocation(
        latitude: _lat!,
        longitude: _lng!,
        speedMs: 0,
        headingDeg: _headingDeg,
        confidence: _confidence * decay * 0.5,
        timestamp: now,
        isPredicted: true,
      );
    }

    // dead reckoning على كرة تقريبية
    final distance = _speedMs * dt;
    final predicted = _offsetMeters(
      _lat!,
      _lng!,
      distance,
      _headingDeg,
    );

    // الثقة تتناقص مع الزمن
    final timeFactor = 1.0 - (dt / maxPredictSeconds);
    final conf = (_confidence * timeFactor).clamp(0.0, 1.0);

    return PredictedLocation(
      latitude: predicted.$1,
      longitude: predicted.$2,
      speedMs: _speedMs,
      headingDeg: _headingDeg,
      confidence: conf,
      timestamp: now,
      isPredicted: true,
    );
  }

  void reset() {
    _lat = null;
    _lng = null;
    _speedMs = 0;
    _headingDeg = 0;
    _lastUpdate = null;
    _confidence = 0;
  }

  double _adaptiveAlpha(double? accuracy, double jump, double dt) {
    var a = positionAlpha;
    // دقة سيئة → نعتمد أكثر على النموذج السابق
    if (accuracy != null && accuracy > 40) {
      a *= 0.6;
    } else if (accuracy != null && accuracy < 15) {
      a = math.min(0.7, a + 0.15);
    }
    // حركة كبيرة وسريعة → نثق بالقراءة أكثر
    if (jump > 15 && dt < 3) {
      a = math.min(0.75, a + 0.2);
    }
    return a.clamp(0.15, 0.85);
  }

  double _confidenceFromAccuracy(double? accuracyMeters) {
    if (accuracyMeters == null) return 0.7;
    if (accuracyMeters <= 10) return 0.95;
    if (accuracyMeters <= 25) return 0.85;
    if (accuracyMeters <= 50) return 0.7;
    if (accuracyMeters <= 100) return 0.5;
    return 0.3;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _normalizeHeading(double deg) {
    var d = deg % 360;
    if (d < 0) d += 360;
    return d;
  }

  static double _lerpHeading(double from, double to, double t) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return _normalizeHeading(from + delta * t);
  }

  static double _distanceMeters(
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

  static double _bearingDegrees(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final y = math.sin(_rad(lng2 - lng1)) * math.cos(_rad(lat2));
    final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.cos(_rad(lng2 - lng1));
    return _normalizeHeading(_deg(math.atan2(y, x)));
  }

  static (double, double) _offsetMeters(
    double lat,
    double lng,
    double distanceM,
    double headingDeg,
  ) {
    const earth = 6371000.0;
    final angDist = distanceM / earth;
    final bearing = _rad(headingDeg);
    final lat1 = _rad(lat);
    final lng1 = _rad(lng);

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angDist) +
          math.cos(lat1) * math.sin(angDist) * math.cos(bearing),
    );
    final lng2 = lng1 +
        math.atan2(
          math.sin(bearing) * math.sin(angDist) * math.cos(lat1),
          math.cos(angDist) - math.sin(lat1) * math.sin(lat2),
        );

    return (_deg(lat2), _deg(lng2));
  }

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
}
