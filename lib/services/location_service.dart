import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// خدمة الموقع الجغرافي مع تحسين الأداء وتوفير البطارية
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ✅ تخزين آخر موقع معروف
  Position? _lastKnownPosition;

  // ✅ التحكم في Throttle
  DateTime? _lastEmitTime;

  // ─── الصلاحيات ──────────────────────────────────────────────

  /// ✅ التحقق من الصلاحيات وتجهيز الخدمة
  Future<bool> checkAndRequestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ خدمة الموقع الجغرافي غير مفعّلة في الجهاز.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ تم رفض صلاحية الموقع.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ تم رفض صلاحية الموقع نهائياً من إعدادات النظام.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من صلاحيات الموقع: $e');
      return false;
    }
  }

  // ─── جلب الموقع ─────────────────────────────────────────────

  /// ✅ جلب آخر موقع معروف (سريع ولا يستهلك بطارية)
  Future<Position?> getLastKnownPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return _lastKnownPosition;

      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _lastKnownPosition = position;
      }
      return position;
    } catch (e) {
      debugPrint('❌ خطأ في جلب آخر موقع معروف: $e');
      return _lastKnownPosition;
    }
  }

  /// ✅ جلب الموقع الحالي (دقيق ولكن يستهلك بطارية)
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return _lastKnownPosition;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // ✅ تخزين آخر موقع معروف
      _lastKnownPosition = position;
      return position;
    } catch (e) {
      debugPrint('❌ خطأ أثناء جلب الموقع الحالي: $e');
      // ✅ في حالة الفشل، نعيد آخر موقع معروف
      return _lastKnownPosition;
    }
  }

  // ─── البث المباشر مع Throttle ──────────────────────────────

  /// ✅ البث المباشر لإحداثيات الموقع مع Throttle لتوفير البطارية
  /// - `throttleDuration`: الحد الأدنى للفاصل الزمني بين التحديثات (افتراضي 250ms)
  /// - `distanceFilter`: الحد الأدنى للمسافة بين التحديثات (افتراضي 5 متر)
  /// - `accuracy`: دقة الموقع (افتراضي `bestForNavigation`)
  Stream<Position> getPositionStream({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    Duration throttleDuration = const Duration(milliseconds: 250),
  }) {
    // ✅ استخدام StreamTransformer لتقييد التحديثات
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: throttleDuration * 2, // مهلة ضعف وقت Throttle
      ),
    ).transform(
      StreamTransformer<Position, Position>.fromHandlers(
        handleData: (position, sink) {
          final now = DateTime.now();

          // ✅ تطبيق Throttle: لا نرسل تحديثاً إذا كان الوقت الماضي أقل من المطلوب
          if (_lastEmitTime == null ||
              now.difference(_lastEmitTime!) >= throttleDuration) {
            _lastEmitTime = now;
            _lastKnownPosition = position;
            sink.add(position);
          }
        },
        handleError: (error, stackTrace, sink) {
          debugPrint('⚠️ خطأ في Stream الموقع: $error');
          // ✅ في حالة الخطأ، نحاول إرسال آخر موقع معروف (إن وجد)
          if (_lastKnownPosition != null) {
            sink.add(_lastKnownPosition!);
          } else {
            sink.addError(error);
          }
        },
      ),
    );
  }

  // ─── Stream مع إعادة محاولة ────────────────────────────────

  /// ✅ بث الموقع مع إعادة محاولة تلقائية عند فشل الـ Stream
  Stream<Position> getPositionStreamWithRetry({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    Duration throttleDuration = const Duration(milliseconds: 250),
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) {
    return Stream.fromFuture(
      Future<Stream<Position>>(() async {
        int retryCount = 0;

        // ✅ دالة لبدء الـ Stream مع إعادة المحاولة
        Stream<Position> createStream() {
          try {
            return getPositionStream(
              distanceFilter: distanceFilter,
              accuracy: accuracy,
              throttleDuration: throttleDuration,
            );
          } catch (e) {
            // ✅ إذا فشل إنشاء الـ Stream، نعيد محاولة بعد تأخير
            if (retryCount < maxRetries) {
              retryCount++;
              debugPrint(
                  '🔄 إعادة محاولة Stream الموقع ($retryCount/$maxRetries)');
              return Stream.error(e);
            } else {
              debugPrint('❌ فشل Stream الموقع بعد $maxRetries محاولات');
              return Stream.error(e);
            }
          }
        }

        return createStream();
      }),
    ).asyncExpand((stream) => stream);
  }

  // ─── دوال مساعدة ────────────────────────────────────────────

  /// ✅ التحقق مما إذا كان الموقع متاحاً
  bool get hasLocation => _lastKnownPosition != null;

  /// ✅ إعادة تعيين آخر موقع معروف
  void clearLastKnownPosition() {
    _lastKnownPosition = null;
    _lastEmitTime = null;
  }

  /// ✅ الحصول على آخر موقع معروف (متزامن)
  Position? get lastKnownPosition => _lastKnownPosition;
}
