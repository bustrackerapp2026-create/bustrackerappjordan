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

/// ملف تتبع الموقع حسب حالة الاستخدام — لتقليل البطارية والبيانات.
enum LocationTrackingProfile {
  /// راكب يتصفح الخريطة: دقة متوسطة ومسافة أكبر
  passengerBrowse,

  /// سائق متاح بدون رحلة
  driverIdle,

  /// سائق أثناء رحلة نشطة
  driverTrip,

  /// أقصى دقة عند الطلب لمرة واحدة (زر موقعي)
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

  /// الحد الأدنى للمسافة بين تحديثات الـ stream (أمتار)
  int get distanceFilterMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 20;
      case LocationTrackingProfile.driverIdle:
        return 25;
      case LocationTrackingProfile.driverTrip:
        return 12;
      case LocationTrackingProfile.preciseOnce:
        return 5;
    }
  }

  /// الحد الأدنى الزمني بين بثّين للتطبيق
  Duration get throttleDuration {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 1);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 2);
      case LocationTrackingProfile.driverTrip:
        return const Duration(milliseconds: 800);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(milliseconds: 400);
    }
  }

  /// الحد الأدنى بين كتابات الموقع إلى Firestore (بيانات)
  Duration get firestoreMinInterval {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return const Duration(seconds: 45);
      case LocationTrackingProfile.driverIdle:
        return const Duration(seconds: 20);
      case LocationTrackingProfile.driverTrip:
        return const Duration(seconds: 10);
      case LocationTrackingProfile.preciseOnce:
        return const Duration(seconds: 15);
    }
  }

  /// الحد الأدنى للمسافة قبل إعادة الكتابة إلى Firestore
  double get firestoreMinDistanceMeters {
    switch (this) {
      case LocationTrackingProfile.passengerBrowse:
        return 80;
      case LocationTrackingProfile.driverIdle:
        return 50;
      case LocationTrackingProfile.driverTrip:
        return 35;
      case LocationTrackingProfile.preciseOnce:
        return 40;
    }
  }
}

/// خدمة الموقع الجغرافي الاحترافية
/// استراتيجية موثوقة: LastKnown → Medium Accuracy → High Accuracy مع Fallback
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  DateTime? _lastEmitTime;

  // ─── الصلاحيات ──────────────────────────────────────────────

  Future<bool> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ خدمة الموقع الجغرافي غير مفعّلة في الجهاز.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ تم رفض صلاحية الموقع.');
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ تم رفض صلاحية الموقع نهائياً من إعدادات النظام.');
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من صلاحيات الموقع: $e');
      return false;
    }
  }

  Future<bool> isPermissionDeniedForever() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // ─── جلب الموقع ─────────────────────────────────────────────

  Future<Position?> getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _lastKnownPosition = position;
      }
      return position ?? _lastKnownPosition;
    } catch (e) {
      debugPrint('❌ خطأ في جلب آخر موقع معروف: $e');
      return _lastKnownPosition;
    }
  }

  Future<Position?> getCurrentPosition({
    bool preferHighAccuracy = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        debugPrint('⚠️ لا توجد صلاحية موقع — إرجاع آخر موقع معروف إن وُجد');
        return _lastKnownPosition;
      }

      Position? bestPosition = await getLastKnownPosition();
      if (bestPosition != null) {
        debugPrint(
            '📍 [Location] LastKnown: ${bestPosition.latitude}, ${bestPosition.longitude}');
      }

      try {
        final medium = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        bestPosition = medium;
        _lastKnownPosition = medium;
        debugPrint(
            '📍 [Location] Medium: ${medium.latitude}, ${medium.longitude} (±${medium.accuracy}m)');

        if (!preferHighAccuracy || medium.accuracy <= 50) {
          return medium;
        }
      } catch (e) {
        debugPrint('⚠️ [Location] فشل Medium accuracy: $e');
      }

      if (preferHighAccuracy) {
        try {
          final high = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: timeout,
              distanceFilter: 0,
            ),
          );
          bestPosition = high;
          _lastKnownPosition = high;
          debugPrint(
              '📍 [Location] High: ${high.latitude}, ${high.longitude} (±${high.accuracy}m)');
          return high;
        } catch (e) {
          debugPrint('⚠️ [Location] فشل High accuracy: $e');
        }
      }

      if (bestPosition != null) {
        debugPrint('📍 [Location] استخدام أفضل نتيجة متاحة (Fallback)');
        return bestPosition;
      }

      try {
        final low = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 6),
          ),
        );
        _lastKnownPosition = low;
        debugPrint(
            '📍 [Location] Low (Network): ${low.latitude}, ${low.longitude}');
        return low;
      } catch (e) {
        debugPrint('❌ [Location] فشل جميع المحاولات: $e');
        return _lastKnownPosition;
      }
    } catch (e) {
      debugPrint('❌ خطأ عام أثناء جلب الموقع الحالي: $e');
      return _lastKnownPosition;
    }
  }

  Future<Position?> getPositionFast() async {
    final last = await getLastKnownPosition();
    if (last != null) return last;
    return getCurrentPosition(preferHighAccuracy: false);
  }

  // ─── البحث عن أماكن ─────────────────────────────────────────

  Future<PlaceSearchResult?> searchPlace(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty) {
      debugPrint('⚠️ لا يوجد MAPBOX_ACCESS_TOKEN للبحث عن الأماكن');
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
      debugPrint('❌ فشل البحث عن المكان: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ─── البث المباشر مع Throttle + ملفات التتبع ────────────────

  Stream<Position> getPositionStream({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration throttleDuration = const Duration(milliseconds: 400),
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
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
          debugPrint('⚠️ خطأ في Stream الموقع: $error');
          if (_lastKnownPosition != null) {
            sink.add(_lastKnownPosition!);
          } else {
            sink.addError(error, stackTrace);
          }
        },
      ),
    );
  }

  /// بث موقع حسب ملف الاستخدام (موفّر للبطارية)
  Stream<Position> getPositionStreamForProfile(
    LocationTrackingProfile profile,
  ) {
    return getPositionStream(
      distanceFilter: profile.distanceFilterMeters,
      accuracy: profile.accuracy,
      throttleDuration: profile.throttleDuration,
    );
  }

  Stream<Position> getPositionStreamWithRetry({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration throttleDuration = const Duration(milliseconds: 400),
    int maxRetries = 3,
  }) {
    return Stream.multi((controller) {
      int retryCount = 0;
      StreamSubscription<Position>? sub;

      void start() {
        sub?.cancel();
        sub = getPositionStream(
          distanceFilter: distanceFilter,
          accuracy: accuracy,
          throttleDuration: throttleDuration,
        ).listen(
          controller.add,
          onError: (e, st) {
            if (retryCount < maxRetries) {
              retryCount++;
              debugPrint(
                  '🔄 إعادة محاولة Stream الموقع ($retryCount/$maxRetries)');
              Future.delayed(Duration(seconds: retryCount), start);
            } else {
              controller.addError(e, st);
            }
          },
          onDone: controller.close,
        );
      }

      controller.onCancel = () => sub?.cancel();
      start();
    });
  }

  bool get hasLocation => _lastKnownPosition != null;

  void clearLastKnownPosition() {
    _lastKnownPosition = null;
    _lastEmitTime = null;
  }

  Position? get lastKnownPosition => _lastKnownPosition;
}
