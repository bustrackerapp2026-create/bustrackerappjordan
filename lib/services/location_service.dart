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

/// ملفات تتبع موفّرة للبطارية حسب حالة الاستخدام.
enum LocationTrackingProfile {
  /// راكب يتصفح فقط
  passengerBrowse,

  /// سائق متاح بدون رحلة
  driverIdle,

  /// سائق أثناء رحلة
  driverTrip,

  /// قراءة لمرة واحدة (زر موقعي)
  preciseOnce,
}

extension LocationTrackingProfileX on LocationTrackingProfile {
  LocationAccuracy get accuracy {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return LocationAccuracy.low;
      case LocationTrackingProfile.driverIdle:
        return LocationAccuracy.low;
      case LocationTrackingProfile.driverTrip:
        return LocationAccuracy.medium;
      case LocationTrackingProfile.preciseOnce:
        return LocationAccuracy.high;
    }
  }

  int get distanceFilterMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 40;
      case LocationTrackingProfile.driverIdle:
        return 45;
      case LocationTrackingProfile.driverTrip:
        return 20;
      case LocationTrackingProfile.preciseOnce:
        return 8;
    }
  }

  Duration get throttleDuration {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 3);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 4);
      case LocationTrackingProfile.driverTrip:
        return const Duration(seconds: 1);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(milliseconds: 500);
    }
  }

  /// فاصل أندرويد بين طلبات الموقع (يوفر بطارية بشكل كبير)
  Duration get androidInterval {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 8);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 10);
      case LocationTrackingProfile.driverTrip:
        return const Duration(seconds: 3);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(seconds: 2);
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
        // يوقف التحديثات عند ثبات الجهاز قدر الإمكان
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
            : ActivityType.other,
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

  Future<bool> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ خدمة الموقع غير مفعّلة');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
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
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) _lastKnownPosition = position;
      return position ?? _lastKnownPosition;
    } catch (e) {
      return _lastKnownPosition;
    }
  }

  /// قراءة لمرة واحدة — تفضّل الدقة المنخفضة أولاً لتوفير البطارية
  Future<Position?> getCurrentPosition({
    bool preferHighAccuracy = false,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return _lastKnownPosition;

      Position? best = await getLastKnownPosition();

      // 1) دقة منخفضة/متوسطة أولاً (أوفر للبطارية)
      try {
        final medium = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: preferHighAccuracy
                ? LocationAccuracy.medium
                : LocationAccuracy.low,
            timeLimit: const Duration(seconds: 6),
          ),
        );
        best = medium;
        _lastKnownPosition = medium;
        if (!preferHighAccuracy || medium.accuracy <= 80) {
          return medium;
        }
      } catch (_) {}

      // 2) عالية فقط عند الحاجة
      if (preferHighAccuracy) {
        try {
          final high = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: timeout,
            ),
          );
          _lastKnownPosition = high;
          return high;
        } catch (_) {}
      }

      return best ?? _lastKnownPosition;
    } catch (e) {
      debugPrint('❌ getCurrentPosition: $e');
      return _lastKnownPosition;
    }
  }

  Future<Position?> getPositionFast() async {
    final last = await getLastKnownPosition();
    if (last != null) return last;
    return getCurrentPosition(preferHighAccuracy: false);
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
    LocationAccuracy accuracy = LocationAccuracy.low,
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
