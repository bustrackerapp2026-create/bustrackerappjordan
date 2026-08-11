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

/// تنبؤ موقع أدق لتتبع سائق/باص:
/// - تنعيم EMA متكيّف حسب دقة GPS
/// - رفض القفزات غير المنطقية (سرعة مستحيلة)
/// - dead reckoning مع **تباطؤ سرعة** (لا سرعة ثابتة للأبد)
/// - اتجاه مستقر عند التوقف ولا يدور عشوائياً
/// - نافذة قصيرة لآخر القراءات لاشتقاق سرعة أوثق
class LocationPredictor {
  double? _lat;
  double? _lng;
  double _speedMs = 0;
  double _headingDeg = 0;
  DateTime? _lastUpdate;
  double _confidence = 0;

  /// تباين تقريبي لفلتر Kalman الخفيف على الموقع
  double _pLat = 25; // m² تقريباً
  double _pLng = 25;

  final List<_Sample> _history = [];
  static const int _maxHistory = 6;

  /// أقصى زمن للتنبؤ قبل التوقف (ثوانٍ)
  final double maxPredictSeconds;

  /// معامل تنعيم الموقع الأساسي
  final double positionAlpha;

  /// معامل تنعيم السرعة
  final double speedAlpha;

  /// أقصى قفزة مقبولة مباشرة (متر)
  final double maxJumpMeters;

  /// أقصى سرعة منطقية لباص حضري (م/ث) ≈ 100 كم/س
  final double maxSpeedMs;

  /// تباطؤ السرعة أثناء التنبؤ (م/ث²) — يقترب من التوقف تدريجياً
  final double coastDecelMs2;

  LocationPredictor({
    this.maxPredictSeconds = 6.0,
    this.positionAlpha = 0.32,
    this.speedAlpha = 0.38,
    this.maxJumpMeters = 90,
    this.maxSpeedMs = 28,
    this.coastDecelMs2 = 1.2,
  });

  bool get hasState => _lat != null && _lng != null;

  /// تغذية بقراءة GPS حقيقية
  PredictedLocation update({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? speedMs,
    double? headingDeg,
    double? accuracyMeters,
  }) {
    if (_lat == null || _lng == null || _lastUpdate == null) {
      return _bootstrap(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        speedMs: speedMs,
        headingDeg: headingDeg,
        accuracyMeters: accuracyMeters,
      );
    }

    final dt = timestamp.difference(_lastUpdate!).inMilliseconds / 1000.0;
    if (dt <= 0.02) {
      // قراءة مكررة/مزدحمة
      return _current(timestamp, predicted: false);
    }

    final jump = _distanceMeters(_lat!, _lng!, latitude, longitude);
    final impliedSpeed = jump / dt;

    // ── رفض شذوذ: سرعة مستحيلة أو قفزة ضخمة مع dt صغير ──
    final isOutlier = impliedSpeed > maxSpeedMs * 1.15 ||
        (jump > maxJumpMeters && dt < 2.5);

    if (isOutlier) {
      // لا نحدّث الحالة بالموقع الشاذ؛ نخفّض الثقة فقط
      _confidence = math.max(0.2, _confidence * 0.7);
      _history.add(_Sample(latitude, longitude, timestamp, accuracyMeters));
      _trimHistory();
      return _current(timestamp, predicted: false);
    }

    // قفزة كبيرة لكن مع زمن كافٍ → إعادة تهيئة جزئية (نفق/تصحيح)
    if (jump > maxJumpMeters) {
      _lat = latitude;
      _lng = longitude;
      if (speedMs != null && speedMs >= 0) {
        _speedMs = speedMs.clamp(0, maxSpeedMs);
      } else {
        _speedMs = impliedSpeed.clamp(0, maxSpeedMs);
      }
      if (headingDeg != null && (speedMs == null || speedMs > 0.6)) {
        _headingDeg = _normalizeHeading(headingDeg);
      }
      _lastUpdate = timestamp;
      _confidence = 0.5;
      _pLat = 40;
      _pLng = 40;
      _pushHistory(latitude, longitude, timestamp, accuracyMeters);
      return _current(timestamp, predicted: false);
    }

    // ── سرعة مقيسة: جهاز أو مشتقة من المسار ──
    final deviceSpeed =
        (speedMs != null && speedMs.isFinite && speedMs > 0.25) ? speedMs : null;
    final pathSpeed = _pathDerivedSpeed(latitude, longitude, timestamp);
    final measuredSpeed =
        (deviceSpeed ?? pathSpeed ?? impliedSpeed).clamp(0.0, maxSpeedMs);

    // عند التوقف الفعلي لا نُبقي سرعة وهمية
    final isStationary = measuredSpeed < 0.45 && jump < 1.5;
    if (isStationary) {
      _speedMs = _lerp(_speedMs, 0, 0.55);
    } else {
      _speedMs = _lerp(_speedMs, measuredSpeed, speedAlpha);
    }

    // ── اتجاه ──
    if (!isStationary) {
      if (headingDeg != null &&
          headingDeg.isFinite &&
          (deviceSpeed == null || deviceSpeed > 0.7)) {
        _headingDeg = _lerpHeading(_headingDeg, headingDeg, 0.4);
      } else if (jump > 2.5) {
        final moved = _bearingDegrees(_lat!, _lng!, latitude, longitude);
        _headingDeg = _lerpHeading(_headingDeg, moved, 0.48);
      }
    }

    // ── دمج Kalman خفيف للموقع ──
    final r = _measurementNoise(accuracyMeters); // تباين القياس
    final q = _processNoise(dt, _speedMs); // تباين العملية

    _pLat += q;
    _pLng += q;

    final kLat = _pLat / (_pLat + r);
    final kLng = _pLng / (_pLng + r);

    // EMA متكيّف كحدّ أدنى/أقصى على كسب Kalman
    final alpha = _adaptiveAlpha(accuracyMeters, jump, dt, kLat);

    _lat = _lerp(_lat!, latitude, alpha);
    _lng = _lerp(_lng!, longitude, alpha);

    _pLat = (1 - kLat) * _pLat;
    _pLng = (1 - kLng) * _pLng;

    _lastUpdate = timestamp;
    _confidence = _confidenceFromAccuracy(accuracyMeters, jump, dt);
    _pushHistory(latitude, longitude, timestamp, accuracyMeters);

    return _current(timestamp, predicted: false);
  }

  /// تنبؤ بين قراءات GPS
  PredictedLocation? predictAt(DateTime now) {
    if (_lat == null || _lng == null || _lastUpdate == null) return null;

    final dt = now.difference(_lastUpdate!).inMilliseconds / 1000.0;
    if (dt <= 0) {
      return _current(now, predicted: false);
    }

    // سرعة متناقصة مع الزمن (coast)
    final coastSpeed = math.max(0.0, _speedMs - coastDecelMs2 * dt);

    if (dt > maxPredictSeconds || coastSpeed < 0.35) {
      final decay = math.max(0.0, 1.0 - (dt / (maxPredictSeconds * 1.4)));
      return PredictedLocation(
        latitude: _lat!,
        longitude: _lng!,
        speedMs: 0,
        headingDeg: _headingDeg,
        confidence: _confidence * decay * 0.45,
        timestamp: now,
        isPredicted: true,
      );
    }

    // مسافة = متوسط السرعة أثناء التباطؤ
    final avgSpeed = (_speedMs + coastSpeed) * 0.5;
    final distance = avgSpeed * dt;

    final predicted = _offsetMeters(
      _lat!,
      _lng!,
      distance,
      _headingDeg,
    );

    final timeFactor = 1.0 - (dt / maxPredictSeconds);
    // ثقة أقل إذا كانت السرعة الأصلية منخفضة أو الدقة السابقة ضعيفة
    final speedFactor = (_speedMs / 8.0).clamp(0.35, 1.0);
    final conf =
        (_confidence * timeFactor * speedFactor).clamp(0.0, 0.95);

    return PredictedLocation(
      latitude: predicted.$1,
      longitude: predicted.$2,
      speedMs: coastSpeed,
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
    _pLat = 25;
    _pLng = 25;
    _history.clear();
  }

  // ─── داخلي ─────────────────────────────────────────────

  PredictedLocation _bootstrap({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? speedMs,
    double? headingDeg,
    double? accuracyMeters,
  }) {
    _lat = latitude;
    _lng = longitude;
    _speedMs = (speedMs ?? 0).clamp(0, maxSpeedMs);
    _headingDeg = _normalizeHeading(headingDeg ?? 0);
    _lastUpdate = timestamp;
    _confidence = _confidenceFromAccuracy(accuracyMeters, 0, 1);
    _pLat = _measurementNoise(accuracyMeters);
    _pLng = _pLat;
    _pushHistory(latitude, longitude, timestamp, accuracyMeters);
    return _current(timestamp, predicted: false);
  }

  PredictedLocation _current(DateTime ts, {required bool predicted}) {
    return PredictedLocation(
      latitude: _lat!,
      longitude: _lng!,
      speedMs: _speedMs,
      headingDeg: _headingDeg,
      confidence: _confidence,
      timestamp: ts,
      isPredicted: predicted,
    );
  }

  void _pushHistory(
    double lat,
    double lng,
    DateTime ts,
    double? accuracy,
  ) {
    _history.add(_Sample(lat, lng, ts, accuracy));
    _trimHistory();
  }

  void _trimHistory() {
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }

  /// سرعة مشتقة من متوسط آخر العينات (أكثر استقراراً من قفزتين فقط)
  double? _pathDerivedSpeed(double lat, double lng, DateTime ts) {
    if (_history.length < 2) return null;
    final oldest = _history.first;
    final dt = ts.difference(oldest.t).inMilliseconds / 1000.0;
    if (dt < 0.4) return null;
    final dist = _distanceMeters(oldest.lat, oldest.lng, lat, lng);
    return (dist / dt).clamp(0.0, maxSpeedMs);
  }

  double _adaptiveAlpha(
    double? accuracy,
    double jump,
    double dt,
    double kalmanGain,
  ) {
    // امزج كسب Kalman مع alpha الأساسي
    var a = (positionAlpha * 0.55) + (kalmanGain * 0.45);

    if (accuracy != null) {
      if (accuracy > 45) {
        a *= 0.55; // دقة سيئة → أبطئ الاستجابة
      } else if (accuracy > 25) {
        a *= 0.75;
      } else if (accuracy < 12) {
        a = math.min(0.78, a + 0.18);
      }
    }

    // حركة واضحة وسريعة → اتبع القراءة أكثر
    if (jump > 12 && dt < 2.5 && (accuracy == null || accuracy < 35)) {
      a = math.min(0.8, a + 0.15);
    }

    return a.clamp(0.12, 0.82);
  }

  double _confidenceFromAccuracy(double? accuracy, double jump, double dt) {
    double base;
    if (accuracy == null) {
      base = 0.72;
    } else if (accuracy <= 8) {
      base = 0.96;
    } else if (accuracy <= 15) {
      base = 0.9;
    } else if (accuracy <= 30) {
      base = 0.8;
    } else if (accuracy <= 50) {
      base = 0.65;
    } else if (accuracy <= 100) {
      base = 0.45;
    } else {
      base = 0.28;
    }

    // ابتكار كبير (jump غير متوقع) يقلل الثقة قليلاً
    if (dt > 0.3 && jump > 25) {
      base *= 0.9;
    }
    return base.clamp(0.15, 0.98);
  }

  double _measurementNoise(double? accuracyMeters) {
    if (accuracyMeters == null || !accuracyMeters.isFinite) return 100;
    final a = accuracyMeters.clamp(3.0, 150.0);
    return a * a; // σ²
  }

  double _processNoise(double dt, double speed) {
    // ضوضاء عملية تعتمد على الزمن والسرعة
    final base = 2.0 + speed * 0.35;
    return (base * base) * math.max(dt, 0.05);
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

class _Sample {
  final double lat;
  final double lng;
  final DateTime t;
  final double? accuracy;

  const _Sample(this.lat, this.lng, this.t, this.accuracy);
}
