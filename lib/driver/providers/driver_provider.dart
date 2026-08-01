import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../models/route_point.dart';
import '../../models/pickup_point.dart';

class DriverProvider extends ChangeNotifier {
  bool _isOnline = false;
  bool _isTripActive = false;
  geo.Position? _currentPosition;

  final List<PickupPoint> _pickupPoints = [];
  final List<RoutePoint> _currentRoute = [];
  List<RoutePoint> _lastRecordedRoute = [];
  bool _isRecordingRoute = false;

  // Getters بأسماء دقيقة ونماذج صريحة
  bool get isOnline => _isOnline;
  bool get isTripActive => _isTripActive;
  geo.Position? get currentPosition => _currentPosition;
  List<PickupPoint> get pickupPoints => List.unmodifiable(_pickupPoints);
  List<RoutePoint> get currentRoute => List.unmodifiable(_currentRoute);
  bool get isRecordingRoute => _isRecordingRoute;

  // ✅ دوال التحقق من صحة الإحداثيات (Validation)
  static bool isValidLatitude(double lat) => lat >= -90.0 && lat <= 90.0;
  static bool isValidLongitude(double lng) => lng >= -180.0 && lng <= 180.0;

  void toggleOnlineStatus() {
    _isOnline = !_isOnline;
    if (!_isOnline && _isTripActive) {
      endTrip();
    }
    notifyListeners();
  }

  /// ✅ شروط حماية (State Guard) لمنع التكرار وبدء رحلة بدون موقع
  void startTrip() {
    if (_isTripActive) return;
    if (_currentPosition == null) {
      throw StateError('لا يمكن بدء الرحلة بدون تحديد الموقع الحالي للسائق.');
    }
    _isTripActive = true;
    _startRecordingRoute();
    notifyListeners();
  }

  /// ✅ شروط حماية ترجع المسار المكتمل بصفة آمنة
  List<RoutePoint> endTrip() {
    if (!_isTripActive) return getRecordedRoute();
    _isTripActive = false;
    final recorded = _stopRecordingRoute();
    notifyListeners();
    return recorded;
  }

  /// ✅ تقليل الـ Rebuilds عبر التحقق من تغير الموقع الفعلي
  void updatePosition(geo.Position position) {
    final bool hasMoved = _currentPosition == null ||
        _currentPosition!.latitude != position.latitude ||
        _currentPosition!.longitude != position.longitude;

    _currentPosition = position;

    bool routeUpdated = false;
    if (_isTripActive && _isRecordingRoute) {
      routeUpdated = _tryAddPointToRoute(position);
    }

    // لا نرسل إشعار لإعادة الرسم إلا عند وجود تغيير حقيقي
    if (hasMoved || routeUpdated) {
      notifyListeners();
    }
  }

  void addPickupPoint(String name, double latitude, double longitude) {
    if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
      throw ArgumentError('الإحداثيات المدخلة لنقطة التجمع غير صالحة.');
    }
    _pickupPoints.add(PickupPoint(
      name: name,
      latitude: latitude,
      longitude: longitude,
    ));
    notifyListeners();
  }

  // ============================================================
  // ✅ إدارة تسجيل المسار
  // ============================================================

  void _startRecordingRoute() {
    _currentRoute.clear();
    _lastRecordedRoute.clear();
    _isRecordingRoute = true;
    if (_currentPosition != null) {
      _tryAddPointToRoute(_currentPosition!);
    }
  }

  bool _tryAddPointToRoute(geo.Position pos) {
    if (!_isRecordingRoute) return false;
    if (!isValidLatitude(pos.latitude) || !isValidLongitude(pos.longitude)) {
      return false;
    }

    if (_currentRoute.isNotEmpty) {
      final lastPoint = _currentRoute.last;
      final distance = _calculateDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (distance < 10) return false; // تجاوز النقاط الأقل من 10 أمتار
    }

    _currentRoute.add(RoutePoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      speed: pos.speed,
      heading: pos.heading,
      accuracy: pos.accuracy,
    ));
    return true;
  }

  List<RoutePoint> _stopRecordingRoute() {
    _isRecordingRoute = false;
    _lastRecordedRoute = List<RoutePoint>.from(_currentRoute);
    _currentRoute.clear();
    return _lastRecordedRoute;
  }

  List<RoutePoint> getRecordedRoute() {
    if (_lastRecordedRoute.isNotEmpty) {
      return List<RoutePoint>.unmodifiable(_lastRecordedRoute);
    }
    return List<RoutePoint>.unmodifiable(_currentRoute);
  }

  /// ✅ حماية لمنع تفريغ المسار أثناء الرحلة الحالية
  void clearRoute() {
    if (_isTripActive) {
      throw StateError('لا يمكن مسح المسار أثناء وجود رحلة نشطة.');
    }
    _currentRoute.clear();
    _lastRecordedRoute.clear();
    _isRecordingRoute = false;
    notifyListeners();
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
