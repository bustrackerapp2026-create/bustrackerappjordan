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

/// خدمة الموقع الجغرافي الاحترافية
/// استراتيجية موثوقة: LastKnown → Medium Accuracy → High Accuracy مع Fallback
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  DateTime? _lastEmitTime;

  // ─── الصلاحيات ──────────────────────────────────────────────

  /// التحقق من تفعيل خدمة الموقع + طلب الصلاحيات بشكل صحيح
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

      // whileInUse أو always مقبولان
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من صلاحيات الموقع: $e');
      return false;
    }
  }

  /// هل يجب فتح إعدادات التطبيق؟ (deniedForever)
  Future<bool> isPermissionDeniedForever() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // ─── جلب الموقع (الاستراتيجية الاحترافية) ───────────────────

  /// جلب آخر موقع معروف بسرعة (لا يستهلك بطارية)
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

  ///
  /// ⭐ الدالة الرئيسية لتحديد الموقع الحالي — موثوقة وسريعة
  ///
  /// الاستراتيجية:
  /// 1. محاولة LastKnown فورية (تجربة مستخدم فورية)
  /// 2. محاولة Medium accuracy (سريعة وموثوقة في معظم الحالات)
  /// 3. محاولة High accuracy مع timeout أطول
  /// 4. إرجاع أفضل نتيجة متاحة + تحديث الكاش
  ///
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

      // ─── المرحلة 1: Last Known (فوري) ───
      Position? bestPosition = await getLastKnownPosition();
      if (bestPosition != null) {
        debugPrint(
            '📍 [Location] LastKnown: ${bestPosition.latitude}, ${bestPosition.longitude}');
      }

      // ─── المرحلة 2: Medium Accuracy (سريعة وموثوقة) ───
      try {
        final medium = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
            // على أندرويد: استخدام LocationManager التقليدي أحياناً أكثر استقراراً
            forceAndroidLocationManager: false,
          ),
        );
        bestPosition = medium;
        _lastKnownPosition = medium;
        debugPrint(
            '📍 [Location] Medium: ${medium.latitude}, ${medium.longitude} (±${medium.accuracy}m)');

        // إذا كانت الدقة جيدة بما فيه الكفاية، نرجع فوراً
        if (medium.accuracy <= 50) {
          return medium;
        }
      } catch (e) {
        debugPrint('⚠️ [Location] فشل Medium accuracy: $e');
      }

      // ─── المرحلة 3: High Accuracy (إذا طُلب) ───
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

      // ─── المرحلة 4: Fallback نهائي ───
      if (bestPosition != null) {
        debugPrint('📍 [Location] استخدام أفضل نتيجة متاحة (Fallback)');
        return bestPosition;
      }

      // محاولة أخيرة بدقة منخفضة جداً (Network-based)
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

  /// نسخة سريعة جداً للاستخدام عند فتح الخريطة (لا تنتظر GPS)
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
      final response = await request.close().timeout(const Duration(seconds: 10));
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

  // ─── البث المباشر مع Throttle ──────────────────────────────

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

  // ─── دوال مساعدة ────────────────────────────────────────────

  bool get hasLocation => _lastKnownPosition != null;

  void clearLastKnownPosition() {
    _lastKnownPosition = null;
    _lastEmitTime = null;
  }

  Position? get lastKnownPosition => _lastKnownPosition;
}
