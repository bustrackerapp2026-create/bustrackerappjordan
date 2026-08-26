import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import 'osm_service.dart';

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

enum LocationFixStage {
  cached,
  quick,
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
        return LocationAccuracy.high;
      case LocationTrackingProfile.driverIdle:
        return LocationAccuracy.high;
      case LocationTrackingProfile.driverTrip:
        return LocationAccuracy.bestForNavigation;
      case LocationTrackingProfile.preciseOnce:
        return LocationAccuracy.bestForNavigation;
    }
  }

  int get distanceFilterMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 12;
      case LocationTrackingProfile.driverIdle:
        return 20;
      case LocationTrackingProfile.driverTrip:
        return 8;
      case LocationTrackingProfile.preciseOnce:
        return 3;
    }
  }

  Duration get throttleDuration {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(milliseconds: 1200);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 3);
      case LocationTrackingProfile.driverTrip:
        return const Duration(milliseconds: 800);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(milliseconds: 300);
    }
  }

  Duration get androidInterval {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 3);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 5);
      case LocationTrackingProfile.driverTrip:
        return const Duration(seconds: 2);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(milliseconds: 800);
    }
  }

  double get maxAcceptableAccuracyMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 55;
      case LocationTrackingProfile.driverIdle:
        return 50;
      case LocationTrackingProfile.driverTrip:
        return 35;
      case LocationTrackingProfile.preciseOnce:
        return 25;
    }
  }

  Duration get firestoreMinInterval {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 90);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 45);
      case LocationTrackingProfile.driverTrip:
        return const Duration(seconds: 15);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(seconds: 20);
    }
  }

  double get firestoreMinDistanceMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 100;
      case LocationTrackingProfile.driverIdle:
        return 70;
      case LocationTrackingProfile.driverTrip:
        return 30;
      case LocationTrackingProfile.preciseOnce:
        return 40;
    }
  }

  bool get usesBackgroundLocation =>
      this == LocationTrackingProfile.driverIdle ||
      this == LocationTrackingProfile.driverTrip;

  LocationSettings toLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        intervalDuration: androidInterval,
        forceLocationManager: false,
        foregroundNotificationConfig: usesBackgroundLocation
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Bus Tracker',
                notificationText: 'جاري مشاركة موقعك مع الركاب',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
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
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: usesBackgroundLocation,
        allowBackgroundLocationUpdates: usesBackgroundLocation,
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
  static const Duration _maxCacheAge = Duration(minutes: 2);
  static const double _goodEnoughMeters = 12;
  static const double _acceptableQuickMeters = 25;

  Future<bool> checkAndRequestPermission() async {
    try {
      final now = DateTime.now();
      if (_permissionGrantedCache == true &&
          _permissionCheckedAt != null &&
          now.difference(_permissionCheckedAt!) < _permissionCacheTtl) {
        return true;
      }

      // الصلاحية فقط — تفعيل GPS من LocationPermissionSheet
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

  Future<LocationPermission> ensureBackgroundLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationPermission.denied;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }

      _permissionGrantedCache =
          permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always;
      _permissionCheckedAt = DateTime.now();
      return permission;
    } catch (e) {
      debugPrint('❌ ensureBackgroundLocationPermission: $e');
      return LocationPermission.denied;
    }
  }

  Future<bool> hasAlwaysPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always;
  }

  Future<bool> isPermissionDeniedForever() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  bool _isFresh(Position p, {Duration maxAge = _maxCacheAge}) {
    try {
      final age = DateTime.now().difference(p.timestamp);
      return age <= maxAge;
    } catch (_) {
      return true;
    }
  }

  bool _isAccurateEnough(Position p, double maxMeters) {
    if (!p.accuracy.isFinite) return false;
    return p.accuracy <= maxMeters;
  }

  Future<Position?> getLastKnownPosition() async {
    try {
      if (_lastKnownPosition != null && _isFresh(_lastKnownPosition!)) {
        unawaited(_refreshSystemLastKnown());
        return _lastKnownPosition;
      }
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        if (_isFresh(position, maxAge: const Duration(minutes: 5))) {
          _lastKnownPosition = _preferBetter(_lastKnownPosition, position);
        }
      }
      return _lastKnownPosition;
    } catch (e) {
      return _lastKnownPosition;
    }
  }

  Future<void> _refreshSystemLastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _lastKnownPosition = _preferBetter(_lastKnownPosition, position);
      }
    } catch (_) {}
  }

  Position? _preferBetter(Position? current, Position candidate) {
    if (current == null) return candidate;

    final ca = current.accuracy.isFinite ? current.accuracy : 9999.0;
    final na = candidate.accuracy.isFinite ? candidate.accuracy : 9999.0;

    final currentAge = DateTime.now().difference(current.timestamp);
    final candidateAge = DateTime.now().difference(candidate.timestamp);

    if (candidateAge < currentAge - const Duration(seconds: 8) &&
        na <= ca + 20) {
      return candidate;
    }

    if (na + 3 < ca) return candidate;

    if ((na - ca).abs() <= 5 && candidate.timestamp.isAfter(current.timestamp)) {
      return candidate;
    }

    if (currentAge > const Duration(minutes: 1) &&
        candidateAge < currentAge &&
        na < 80) {
      return candidate;
    }

    return current;
  }

  LocationSettings _settings({
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
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );
  }

  Future<Position?> locateProgressive({
    void Function(Position position, LocationFixStage stage)? onProgress,
    bool refineToPrecise = true,
    Duration quickTimeout = const Duration(seconds: 5),
    Duration preciseTimeout = const Duration(seconds: 15),
  }) async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return _lastKnownPosition;

    Position? best;

    final cached = await getLastKnownPosition();
    if (cached != null && _isFresh(cached)) {
      best = cached;
      _lastKnownPosition = cached;
      onProgress?.call(cached, LocationFixStage.cached);
    }

    try {
      final quick = await Geolocator.getCurrentPosition(
        locationSettings: _settings(
          accuracy: LocationAccuracy.medium,
          timeLimit: quickTimeout,
        ),
      );
      best = _preferBetter(best, quick);
      _lastKnownPosition = best;
      // أبلغ بأفضل نقطة متاحة وليس العينة الخام فقط — يقلل قفزات الكاميرا
      onProgress?.call(best!, LocationFixStage.quick);

      if (_isAccurateEnough(quick, _goodEnoughMeters)) {
        if (refineToPrecise) {
          unawaited(_refineInBackground(onProgress));
        }
        return best;
      }

      if (!refineToPrecise || _isAccurateEnough(quick, _acceptableQuickMeters)) {
        if (refineToPrecise) {
          unawaited(_refineInBackground(onProgress));
        }
        return best;
      }
    } catch (e) {
      debugPrint('⚠️ [Location] quick fix: $e');
    }

    if (refineToPrecise) {
      final precise = await _collectBestPrecise(
        timeBudget: preciseTimeout,
        onProgress: onProgress,
      );
      if (precise != null) {
        best = _preferBetter(best, precise);
        _lastKnownPosition = best;
      }
    }

    return best ?? _lastKnownPosition;
  }

  Future<Position?> _collectBestPrecise({
    required Duration timeBudget,
    void Function(Position position, LocationFixStage stage)? onProgress,
  }) async {
    Position? best;
    final deadline = DateTime.now().add(timeBudget);
    var attempts = 0;

    while (DateTime.now().isBefore(deadline) && attempts < 5) {
      attempts++;
      final remaining = deadline.difference(DateTime.now());
      if (remaining < const Duration(milliseconds: 400)) break;

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _settings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: remaining > const Duration(seconds: 5)
                ? const Duration(seconds: 5)
                : remaining,
          ),
        );
        best = _preferBetter(best, pos);
        onProgress?.call(best!, LocationFixStage.precise);

        if (_isAccurateEnough(pos, _goodEnoughMeters)) break;
      } catch (e) {
        debugPrint('⚠️ [Location] precise sample $attempts: $e');
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    return best;
  }

  Future<void> _refineInBackground(
    void Function(Position position, LocationFixStage stage)? onProgress,
  ) async {
    try {
      final precise = await _collectBestPrecise(
        timeBudget: const Duration(seconds: 8),
        onProgress: onProgress,
      );
      if (precise != null) {
        _lastKnownPosition = _preferBetter(_lastKnownPosition, precise);
      }
    } catch (_) {}
  }

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
    if (last != null &&
        _isFresh(last) &&
        _isAccurateEnough(last, _acceptableQuickMeters)) {
      return last;
    }
    return locateProgressive(
      refineToPrecise: true,
      quickTimeout: const Duration(seconds: 2),
      preciseTimeout: const Duration(seconds: 5),
    );
  }

  /// بحث مكان: OpenStreetMap أولاً (عربي / الأردن)، ثم Mapbox كاحتياطي.
  Future<PlaceSearchResult?> searchPlace(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      final osm = await OsmService().searchPlace(query);
      if (osm != null) return osm;
    } catch (e) {
      debugPrint('⚠️ OSM search fallback: $e');
    }

    return _searchPlaceMapbox(query);
  }

  Future<PlaceSearchResult?> _searchPlaceMapbox(String query) async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty || token == 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') {
      return null;
    }

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
      debugPrint('❌ searchPlace Mapbox: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Stream<Position> getPositionStream({
    int distanceFilter = 12,
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration throttleDuration = const Duration(milliseconds: 1200),
    LocationSettings? settings,
    double maxAccuracyMeters = 60,
  }) {
    Position? lastAccepted;

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

          if (position.accuracy.isFinite &&
              position.accuracy > maxAccuracyMeters &&
              lastAccepted != null &&
              _isAccurateEnough(lastAccepted!, maxAccuracyMeters) &&
              now.difference(lastAccepted!.timestamp) <
                  const Duration(seconds: 20)) {
            return;
          }

          if (_lastEmitTime != null &&
              now.difference(_lastEmitTime!) < throttleDuration) {
            final improved = lastAccepted != null &&
                position.accuracy.isFinite &&
                lastAccepted!.accuracy.isFinite &&
                position.accuracy + 8 < lastAccepted!.accuracy;
            if (!improved) return;
          }

          _lastEmitTime = now;
          lastAccepted = position;
          _lastKnownPosition = _preferBetter(_lastKnownPosition, position);
          sink.add(position);
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
      maxAccuracyMeters: profile.maxAcceptableAccuracyMeters,
    );
  }

  bool get hasLocation => _lastKnownPosition != null;

  void clearLastKnownPosition() {
    _lastKnownPosition = null;
    _lastEmitTime = null;
  }

  Position? get lastKnownPosition => _lastKnownPosition;
}
