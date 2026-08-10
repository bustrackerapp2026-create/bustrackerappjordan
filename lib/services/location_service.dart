import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

class PlaceSearchResult {
  final String name;
  final double latitude;
  final double longitude;

  const PlaceSearchResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

/// مراحل تثبيت الموقع (مثل جوجل ماب: فوري → تقريبي → دقيق)
enum LocationFixStage {
  /// من الذاكرة / آخر موقع معروف للنظام — فوري تقريباً
  cached,

  /// أول تثبيت سريع من مزوّد الموقع
  quick,

  /// تثبيت أدق بعد التحسين
  precise,
}

enum LocationTrackingProfile {
  passengerBrowse,
  driverIdle,
  driverTrip,
  preciseOnce,
}

extension LocationTrackingProfileX on LocationTrackingProfile {
  LocationAccuracy get accuracy {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return LocationAccuracy.medium;
      case LocationTrackingProfile.driverIdle:
        return LocationAccuracy.medium;
      case LocationTrackingProfile.driverTrip:
        return LocationAccuracy.high;
      case LocationTrackingProfile.preciseOnce:
        return LocationAccuracy.high;
    }
  }

  int get distanceFilterMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 25;
      case LocationTrackingProfile.driverIdle:
        return 30;
      case LocationTrackingProfile.driverTrip:
        return 15;
      case LocationTrackingProfile.preciseOnce:
        return 5;
    }
  }

  Duration get throttleDuration {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 2);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 3);
      case LocationTrackingProfile.driverTrip:
        return const Duration(milliseconds: 800);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(milliseconds: 400);
    }
  }

  Duration get androidInterval {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 5);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 7);
      case LocationTrackingProfile.driverTrip:
        return const Duration(seconds: 2);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(seconds: 1);
    }
  }

  Duration get firestoreMinInterval {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 90);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 40);
      case LocationTrackingProfile.driverTrip:
        return const Duration(seconds: 15);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(seconds: 20);
    }
  }

  double get firestoreMinDistanceMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 120;
      case LocationTrackingProfile.driverIdle:
        return 80;
      case LocationTrackingProfile.driverTrip:
        return 40;
      case LocationTrackingProfile.preciseOnce:
        return 50;
    }
  }

  LocationSettings toLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        intervalDuration: androidInterval,
        // Fused Location Provider — أسرع مثل تطبيقات جوجل
        forceLocationManager: false,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        activityType: this == LocationTrackingProfile.driverTrip
            ? ActivityType.automotiveNavigation
            : ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    }

    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  DateTime? _lastEmitTime;
  bool? _permissionGrantedCache;
  DateTime? _permissionCheckedAt;

  static const Duration _permissionCacheTtl = Duration(seconds: 45);

  Future<bool> checkAndRequestPermission() async {
    try {
      final now = DateTime.now();
      if (_permissionGrantedCache == true &&
          _permissionCheckedAt != null &&
          now.difference(_permissionCheckedAt!) < _permissionCacheTtl) {
        return true;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionGrantedCache = false;
        _permissionCheckedAt = now;
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      _permissionGrantedCache = granted;
      _permissionCheckedAt = now;
      return granted;
    } catch (e) {
      debugPrint('❌ صلاحيات الموقع: $e');
      return false;
    }
  }

  Future<bool> isPermissionDeniedForever() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<Position?> getLastKnownPosition() async {
    try {
      // ذاكرة التطبيق أولاً (فوري)
      if (_lastKnownPosition != null) {
        // حدّث من النظام في الخلفية دون انتظار النتيجة للمسار السريع
        unawaited(_refreshSystemLastKnown());
        return _lastKnownPosition;
      }
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) _lastKnownPosition = position;
      return position;
    } catch (e) {
      return _lastKnownPosition;
    }
  }

  Future<void> _refreshSystemLastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) _lastKnownPosition = position;
    } catch (_) {}
  }

  Position? _preferBetter(Position? current, Position candidate) {
    if (current == null) return candidate;
    // دقة أصغر رقم = أفضل
    final ca = current.accuracy;
    final na = candidate.accuracy;
    if (!na.isFinite) return current;
    if (!ca.isFinite) return candidate;
    if (na + 5 < ca) return candidate;
    // أحدث بكثير مع دقة مقبولة
    if (candidate.timestamp.isAfter(current.timestamp) && na <= ca + 25) {
      return candidate;
    }
    return current;
  }

  LocationSettings _androidOrDefault({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
    int distanceFilter = 0,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );
  }

  /// تحديد موقع بأسلوب Google Maps:
  /// 1) cached فوري → 2) quick سريع → 3) precise تحسين
  /// [onProgress] يُستدعى فور كل تحسّن لعرض العلامة فوراً على الخريطة.
  Future<Position?> locateProgressive({
    void Function(Position position, LocationFixStage stage)? onProgress,
    bool refineToPrecise = true,
    Duration quickTimeout = const Duration(seconds: 3),
    Duration preciseTimeout = const Duration(seconds: 7),
  }) async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return _lastKnownPosition;

    Position? best;

    // ── 1) فوري: آخر موقع معروف ───────────────────────────
    final cached = await getLastKnownPosition();
    if (cached != null) {
      best = cached;
      _lastKnownPosition = cached;
      onProgress?.call(cached, LocationFixStage.cached);
    }

    // ── 2) سريع: high عبر Fused (غالباً يعيد كاش النظام خلال <1ث) ──
    try {
      final quick = await Geolocator.getCurrentPosition(
        locationSettings: _androidOrDefault(
          accuracy: LocationAccuracy.high,
          timeLimit: quickTimeout,
        ),
      );
      best = _preferBetter(best, quick);
      _lastKnownPosition = best;
      onProgress?.call(quick, LocationFixStage.quick);

      // إن كانت الدقة جيدة كفاية نتخطى الانتظار الطويل
      if (!refineToPrecise || quick.accuracy <= 40) {
        // حسّن في الخلفية بدون حجب الإرجاع
        if (refineToPrecise && quick.accuracy > 15) {
          unawaited(_refineInBackground(onProgress));
        }
        return best;
      }
    } catch (e) {
      debugPrint('⚠️ [Location] quick fix: $e');
    }

    // ── 3) أدق عند الحاجة ─────────────────────────────────
    if (refineToPrecise) {
      try {
        final precise = await Geolocator.getCurrentPosition(
          locationSettings: _androidOrDefault(
            accuracy: LocationAccuracy.best,
            timeLimit: preciseTimeout,
          ),
        );
        best = _preferBetter(best, precise);
        _lastKnownPosition = best;
        onProgress?.call(precise, LocationFixStage.precise);
      } catch (e) {
        debugPrint('⚠️ [Location] precise fix: $e');
      }
    }

    return best ?? _lastKnownPosition;
  }

  Future<void> _refineInBackground(
    void Function(Position position, LocationFixStage stage)? onProgress,
  ) async {
    try {
      final precise = await Geolocator.getCurrentPosition(
        locationSettings: _androidOrDefault(
          accuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 8),
        ),
      );
      _lastKnownPosition = _preferBetter(_lastKnownPosition, precise);
      onProgress?.call(precise, LocationFixStage.precise);
    } catch (_) {}
  }

  /// للتوافق مع الاستدعاءات القديمة — يستخدم المسار السريع
  Future<Position?> getCurrentPosition({
    bool preferHighAccuracy = true,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return locateProgressive(
      refineToPrecise: preferHighAccuracy,
      quickTimeout: const Duration(seconds: 3),
      preciseTimeout: timeout,
    );
  }

  Future<Position?> getPositionFast() async {
    final last = await getLastKnownPosition();
    if (last != null) return last;
    return locateProgressive(
      refineToPrecise: false,
      quickTimeout: const Duration(seconds: 2),
    );
  }

  Future<PlaceSearchResult?> searchPlace(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty) return null;

    final encodedQuery = Uri.encodeComponent(query.trim());
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
      '?access_token=$token&country=jo&limit=1&language=ar',
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok) return null;

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final feature = features.first as Map<String, dynamic>;
      final center = feature['center'] as List<dynamic>?;
      final placeName = feature['place_name'] as String? ?? query.trim();
      if (center == null || center.length < 2) return null;

      return PlaceSearchResult(
        name: placeName,
        longitude: (center[0] as num).toDouble(),
        latitude: (center[1] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('❌ searchPlace: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Stream<Position> getPositionStream({
    int distanceFilter = 25,
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration throttleDuration = const Duration(seconds: 2),
    LocationSettings? settings,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: settings ??
          LocationSettings(
            accuracy: accuracy,
            distanceFilter: distanceFilter,
          ),
    ).transform(
      StreamTransformer<Position, Position>.fromHandlers(
        handleData: (position, sink) {
          final now = DateTime.now();
          if (_lastEmitTime == null ||
              now.difference(_lastEmitTime!) >= throttleDuration) {
            _lastEmitTime = now;
            _lastKnownPosition = position;
            sink.add(position);
          }
        },
        handleError: (error, stackTrace, sink) {
          if (_lastKnownPosition != null) {
            sink.add(_lastKnownPosition!);
          } else {
            sink.addError(error, stackTrace);
          }
        },
      ),
    );
  }

  Stream<Position> getPositionStreamForProfile(
    LocationTrackingProfile profile,
  ) {
    return getPositionStream(
      distanceFilter: profile.distanceFilterMeters,
      accuracy: profile.accuracy,
      throttleDuration: profile.throttleDuration,
      settings: profile.toLocationSettings(),
    );
  }

  bool get hasLocation => _lastKnownPosition != null;

  void clearLastKnownPosition() {
    _lastKnownPosition = null;
    _lastEmitTime = null;
  }

  Position? get lastKnownPosition => _lastKnownPosition;
}
