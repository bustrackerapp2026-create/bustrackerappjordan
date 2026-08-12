import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../models/route_point.dart';
import '../../models/pickup_point.dart';

/// حالة تشغيل سائق واحد فقط — مربوطة بـ [boundUserId].
/// يجب استدعاء [bindToUser] عند دخول السائق و [reset] عند الخروج.
class DriverProvider extends ChangeNotifier {
  /// معرّف السائق الذي تخصّه هذه الحالة. null = لا يوجد سائق مربوط.
  String? _boundUserId;

  bool _isOnline = false;
  bool _isTripActive = false;
  geo.Position? _currentPosition;

  final List<PickupPoint> _pickupPoints = [];
  final List<RoutePoint> _currentRoute = [];
  List<RoutePoint> _lastRecordedRoute = [];
  bool _isRecordingRoute = false;

  String? get boundUserId => _boundUserId;
  bool get isBound => _boundUserId != null && _boundUserId!.isNotEmpty;

  bool get isOnline => _isOnline;
  bool get isTripActive => _isTripActive;
  geo.Position? get currentPosition => _currentPosition;
  List<PickupPoint> get pickupPoints => List.unmodifiable(_pickupPoints);
  List<RoutePoint> get currentRoute => List.unmodifiable(_currentRoute);
  bool get isRecordingRoute => _isRecordingRoute;

  static bool isValidLatitude(double lat) => lat >= -90.0 && lat <= 90.0;
  static bool isValidLongitude(double lng) => lng >= -180.0 && lng <= 180.0;

  /// ربط الحالة بسائق معيّن. إن تغيّر المعرّف تُصفَّر الحالة السابقة.
  void bindToUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) {
      reset();
      return;
    }
    if (_boundUserId == id) return;
    _clearSessionState();
    _boundUserId = id;
    notifyListeners();
  }

  /// مزامنة الحالة من Firestore لهذا السائق فقط (بعد bind).
  void syncFromRemote({
    required String userId,
    required bool isOnline,
    required bool isTripActive,
  }) {
    if (_boundUserId != userId) {
      bindToUser(userId);
    }
    var changed = false;
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      changed = true;
    }
    if (_isTripActive != isTripActive) {
      _isTripActive = isTripActive;
      if (!isTripActive) {
        _isRecordingRoute = false;
        _currentRoute.clear();
      } else if (!_isRecordingRoute) {
        _startRecordingRoute();
      }
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// تصفير كامل — يُستدعى عند تسجيل الخروج أو تبديل الحساب.
  void reset() {
    _boundUserId = null;
    _clearSessionState();
    notifyListeners();
  }

  void _clearSessionState() {
    _isOnline = false;
    _isTripActive = false;
    _currentPosition = null;
    _pickupPoints.clear();
    _currentRoute.clear();
    _lastRecordedRoute.clear();
    _isRecordingRoute = false;
  }

  bool _ensureBound([String? expectedUserId]) {
    if (!isBound) {
      debugPrint('DriverProvider: رفض العملية — لا يوجد سائق مربوط');
      return false;
    }
    if (expectedUserId != null &&
        expectedUserId.isNotEmpty &&
        _boundUserId != expectedUserId) {
      debugPrint(
        'DriverProvider: رفض العملية — userId=$expectedUserId '
        'لا يطابق bound=$_boundUserId',
      );
      return false;
    }
    return true;
  }

  /// تبديل التوصيل لهذا السائق فقط.
  bool toggleOnlineStatus({String? userId}) {
    if (!_ensureBound(userId)) return false;
    _isOnline = !_isOnline;
    if (!_isOnline && _isTripActive) {
      _isTripActive = false;
      _stopRecordingRoute();
    }
    notifyListeners();
    return true;
  }

  bool setOnline(bool value, {String? userId}) {
    if (!_ensureBound(userId)) return false;
    if (_isOnline == value) return true;
    _isOnline = value;
    if (!_isOnline && _isTripActive) {
      _isTripActive = false;
      _stopRecordingRoute();
    }
    notifyListeners();
    return true;
  }

  /// بدء رحلة لهذا السائق فقط.
  bool startTrip({String? userId}) {
    if (!_ensureBound(userId)) return false;
    if (_isTripActive) return false;
    if (_currentPosition == null) {
      throw StateError('لا يمكن بدء الرحلة بدون تحديد الموقع الحالي للسائق.');
    }
    if (!_isOnline) {
      throw StateError('يجب تفعيل التوصيل قبل بدء الرحلة.');
    }
    _isTripActive = true;
    _startRecordingRoute();
    notifyListeners();
    return true;
  }

  /// إنهاء رحلة هذا السائق فقط.
  List<RoutePoint> endTrip({String? userId}) {
    if (!_ensureBound(userId)) return const [];
    if (!_isTripActive) return getRecordedRoute();
    _isTripActive = false;
    final recorded = _stopRecordingRoute();
    notifyListeners();
    return recorded;
  }

  void updatePosition(geo.Position position, {String? userId}) {
    if (!_ensureBound(userId)) return;

    final bool hasMoved = _currentPosition == null ||
        _currentPosition!.latitude != position.latitude ||
        _currentPosition!.longitude != position.longitude;

    _currentPosition = position;

    bool routeUpdated = false;
    if (_isTripActive && _isRecordingRoute) {
      routeUpdated = _tryAddPointToRoute(position);
    }

    if (hasMoved || routeUpdated) {
      notifyListeners();
    }
  }

  void addPickupPoint(String name, double latitude, double longitude) {
    if (!isBound) return;
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
      if (distance < 10) return false;
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
