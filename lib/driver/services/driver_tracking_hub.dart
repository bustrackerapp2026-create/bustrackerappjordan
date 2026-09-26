import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../models/trip_ping.dart';
import '../../services/location_service.dart';
import '../../services/trip_ping_buffer.dart';
import '../../services/trip_ping_service.dart';
import '../../services/vehicle_trip_service.dart';
import 'driver_tracking_lifecycle.dart';

/// نقطة مركزية لتتبع السائق — تبقى حية حتى لو أُغلقت شاشة الخريطة.
///
/// الاستخدام:
/// - السائق «متصل» أو في رحلة → [requestStart]
/// - غير متصل → [requestStop]
/// - واجهة الخريطة تسجّل [mapUiHandler] لعرض العلامة فقط
class DriverTrackingHub {
  DriverTrackingHub._() {
    _lifecycle.onPosition = _dispatchPosition;
    _lifecycle.onStateChanged = (s) {
      if (kDebugMode) {
        debugPrint('🛰️ DriverTrackingHub state=$s');
      }
    };
  }

  static final DriverTrackingHub instance = DriverTrackingHub._();

  final DriverTrackingLifecycle _lifecycle = DriverTrackingLifecycle();

  /// يحدّث خريطة السائق إن كانت مفتوحة (اختياري).
  void Function(geo.Position position)? mapUiHandler;

  bool _wantOnline = false;
  bool _wantTrip = false;

  final VehicleTripService _vehicleTripService = VehicleTripService();

  String? _activeVehicleTripId;
  DateTime? _lastVehicleTripLocationWriteAt;
  Timer? _vehicleTripFlushTimer;
  bool _vehicleTripWriteInFlight = false;
  geo.Position? _pendingVehicleTripPosition;

  final TripPingBuffer _tripPingBuffer = TripPingBuffer();
  final TripPingService _tripPingService = TripPingService();
  Future<void>? _tripPingUploadFuture;
  Timer? _tripPingUploadTimer;
  bool _historicalCapturePaused = false;
  String? _activeVehicleTripRouteId;
  String? _activeVehicleTripDirection;
  DateTime? _lastHistoricalPingAt;

  static const Duration _vehicleTripLocationInterval =
      Duration(seconds: 5);
  // المرحلة الأولى تستخدم نفس cadence الحالة الحية حتى لا ننشئ
  // معدل GPS مستقلًا قبل تثبيت سياسة Historical Sampling النهائية.
  static const Duration _historicalPingInterval = Duration(seconds: 5);
  static const Duration _historicalUploadInterval = Duration(seconds: 20);
  static const int _historicalBatchSize = 5;

  DriverTrackingState get state => _lifecycle.state;
  bool get isRunning => _lifecycle.isRunning;
  geo.Position? get lastPosition => _lifecycle.lastPosition;

  int get bufferedTripPingCount => _tripPingBuffer.length;

  /// يربط الـHub بمعرف VehicleTrip النشطة وبياناتها اللازمة للتسجيل التاريخي.
  ///
  /// بيانات Historical تبقى أولًا في الـBuffer، ثم تُرفع على دفعات أثناء
  /// الرحلة، مع Flush نهائي قبل إنهاء VehicleTrip.
  ///
  /// يربط الـHub بمعرف VehicleTrip النشطة حتى يستمر التحديث
  /// حتى لو أُغلقت واجهة الخريطة أو تغيرت الشاشة.
  void setActiveVehicleTrip(
    String? tripId, {
    String? routeId,
    String? direction,
  }) {
    final normalized = tripId?.trim();
    _vehicleTripFlushTimer?.cancel();
    _vehicleTripFlushTimer = null;
    _tripPingUploadTimer?.cancel();
    _tripPingUploadTimer = null;
    _historicalCapturePaused = false;

    if (normalized == null || normalized.isEmpty) {
      _activeVehicleTripId = null;
      _activeVehicleTripRouteId = null;
      _activeVehicleTripDirection = null;
      _lastVehicleTripLocationWriteAt = null;
      _lastHistoricalPingAt = null;
      _pendingVehicleTripPosition = null;
      return;
    }

    final normalizedRouteId = routeId?.trim();
    final normalizedDirection = direction?.trim().toLowerCase();

    if (_activeVehicleTripId == normalized) {
      if (normalizedRouteId != null && normalizedRouteId.isNotEmpty) {
        _activeVehicleTripRouteId = normalizedRouteId;
      }
      if (normalizedDirection != null && normalizedDirection.isNotEmpty) {
        _activeVehicleTripDirection = normalizedDirection;
      }
      _scheduleHistoricalTripPingUpload();
      return;
    }

    _activeVehicleTripId = normalized;
    _activeVehicleTripRouteId =
        normalizedRouteId?.isNotEmpty == true ? normalizedRouteId : null;
    _activeVehicleTripDirection =
        normalizedDirection?.isNotEmpty == true ? normalizedDirection : null;
    _lastVehicleTripLocationWriteAt = null;
    _lastHistoricalPingAt = null;
    _pendingVehicleTripPosition = null;
    _scheduleHistoricalTripPingUpload();
  }

  void clearActiveVehicleTrip() {
    setActiveVehicleTrip(null);
  }

  void _scheduleHistoricalTripPingUpload() {
    if (_activeVehicleTripId == null || _activeVehicleTripId!.isEmpty) {
      return;
    }
    _tripPingUploadTimer?.cancel();
    _tripPingUploadTimer = Timer(
      _historicalUploadInterval,
      () => unawaited(
        flushHistoricalTripPings(),
      ),
    );
  }

  Future<void> _runHistoricalTripPingUpload({required bool force}) async {
    if (_historicalCapturePaused && !force) return;
    final batch = _tripPingBuffer.peekBatch(TripPingService.maxBatchSize);
    if (batch.isEmpty) return;
    if (!force && batch.length < _historicalBatchSize) return;

    _tripPingUploadFuture = Future<void>(() async {
      await _tripPingService.uploadBatch(batch);
      _tripPingBuffer.removeFirst(batch.length);
    });

    try {
      await _tripPingUploadFuture!;
    } finally {
      _tripPingUploadFuture = null;
    }
  }

  Future<void> flushHistoricalTripPings({bool force = false}) async {
    if (_activeVehicleTripId == null || _activeVehicleTripId!.isEmpty) return;

    if (_tripPingUploadFuture != null) {
      await _tripPingUploadFuture;
    }

    if (force) {
      _historicalCapturePaused = true;
    }

    try {
      while (!_tripPingBuffer.isEmpty) {
        await _runHistoricalTripPingUpload(force: true);
      }
    } catch (e) {
      if (force) {
        _historicalCapturePaused = false;
        rethrow;
      }
      debugPrint('🧭 Historical TripPing batch upload failed: $e');
    } finally {
      _tripPingUploadTimer?.cancel();
      _tripPingUploadTimer = null;
      if (!force &&
          _activeVehicleTripId != null &&
          _activeVehicleTripId!.isNotEmpty &&
          !_tripPingBuffer.isEmpty) {
        _scheduleHistoricalTripPingUpload();
      }
    }
  }

  void _captureHistoricalTripPing(geo.Position position) {
    if (_historicalCapturePaused) return;

    final tripId = _activeVehicleTripId;
    final routeId = _activeVehicleTripRouteId;
    final direction = _activeVehicleTripDirection;
    if (tripId == null || tripId.isEmpty) return;
    if (routeId == null || routeId.isEmpty) return;
    if (direction == null || direction.isEmpty) return;

    final now = DateTime.now();
    final last = _lastHistoricalPingAt;
    if (last != null &&
        now.difference(last) < _historicalPingInterval) {
      return;
    }

    final ping = TripPing(
      tripId: tripId,
      routeId: routeId,
      direction: direction,
      location: GeoPoint(position.latitude, position.longitude),
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
    );

    if (_tripPingBuffer.tryAdd(ping)) {
      _lastHistoricalPingAt = now;
      if (_tripPingBuffer.length >= _historicalBatchSize) {
        unawaited(flushHistoricalTripPings());
      }
      _scheduleHistoricalTripPingUpload();
      if (kDebugMode) {
        debugPrint(
          '🧭 TripPing buffered: trip=$tripId count=${_tripPingBuffer.length}',
        );
      }
    } else if (kDebugMode) {
      debugPrint('🧭 TripPing buffer full or invalid; point not buffered.');
    }
  }

  void _queueActiveVehicleTripPosition(geo.Position position) {
    final tripId = _activeVehicleTripId;
    if (tripId == null || tripId.isEmpty) return;

    _pendingVehicleTripPosition = position;
    if (_vehicleTripWriteInFlight) return;

    final last = _lastVehicleTripLocationWriteAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _vehicleTripLocationInterval) {
        _scheduleVehicleTripFlush(_vehicleTripLocationInterval - elapsed);
        return;
      }
    }

    unawaited(_flushActiveVehicleTripPosition());
  }

  void _scheduleVehicleTripFlush(Duration delay) {
    if (_activeVehicleTripId == null || _activeVehicleTripId!.isEmpty) {
      return;
    }
    _vehicleTripFlushTimer?.cancel();
    _vehicleTripFlushTimer = Timer(
      delay,
      () => unawaited(_flushActiveVehicleTripPosition()),
    );
  }

  Future<void> _flushActiveVehicleTripPosition() async {
    if (_vehicleTripWriteInFlight) return;

    final tripId = _activeVehicleTripId;
    final position = _pendingVehicleTripPosition;
    if (tripId == null || tripId.isEmpty || position == null) return;

    final last = _lastVehicleTripLocationWriteAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _vehicleTripLocationInterval) {
        _scheduleVehicleTripFlush(_vehicleTripLocationInterval - elapsed);
        return;
      }
    }

    _pendingVehicleTripPosition = null;
    _vehicleTripWriteInFlight = true;
    try {
      await _vehicleTripService.updateLiveLocation(
        tripId: tripId,
        currentLocation: GeoPoint(position.latitude, position.longitude),
        speed: position.speed,
        heading: position.heading,
      );
      if (_activeVehicleTripId == tripId) {
        _lastVehicleTripLocationWriteAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('🛰️ VehicleTrip live update failed: $e');
      if (_activeVehicleTripId == tripId) {
        _lastVehicleTripLocationWriteAt = DateTime.now();
      }
    } finally {
      _vehicleTripWriteInFlight = false;
      if (_activeVehicleTripId == tripId &&
          _pendingVehicleTripPosition != null) {
        final latest = _lastVehicleTripLocationWriteAt;
        if (latest == null) {
          unawaited(_flushActiveVehicleTripPosition());
        } else {
          final elapsed = DateTime.now().difference(latest);
          if (elapsed >= _vehicleTripLocationInterval) {
            unawaited(_flushActiveVehicleTripPosition());
          } else {
            _scheduleVehicleTripFlush(
              _vehicleTripLocationInterval - elapsed,
            );
          }
        }
      }
    }
  }

  void _dispatchPosition(geo.Position pos) {
    final ui = mapUiHandler;
    if (ui != null) {
      ui(pos);
    } else if (_wantOnline || _wantTrip) {
      // لا واجهة خريطة: ارفع الموقع للخادم مباشرة.
      unawaited(
        _lifecycle.uploadLocation(
          position: pos,
          isOnline: _wantOnline,
          isTripActive: _wantTrip,
        ),
      );
    }

    // التسجيل التاريخي مستقل عن واجهة الخريطة، لكنه يبقى محليًا في الـBuffer.
    _captureHistoricalTripPing(pos);

    // تحديث آخر حالة VehicleTrip مستقل عن وجود واجهة الخريطة.
    _queueActiveVehicleTripPosition(pos);
  }

  Future<void> requestStart({
    required String uid,
    required LocationTrackingProfile profile,
    required bool isOnline,
    required bool isTripActive,
  }) async {
    _wantOnline = isOnline;
    _wantTrip = isTripActive;
    if (!isOnline && !isTripActive) {
      await requestStop();
      return;
    }
    await _lifecycle.requestStart(uid: uid, profile: profile);
  }

  Future<void> requestStop() async {
    _wantOnline = false;
    _wantTrip = false;
    await _lifecycle.requestStop();
  }

  /// عند تسجيل الخروج — إيقاف كامل.
  Future<void> shutdown() async {
    mapUiHandler = null;
    clearActiveVehicleTrip();
    await requestStop();
  }

  Future<void> uploadLocation({
    required geo.Position position,
    required bool isOnline,
    required bool isTripActive,
    String? fullName,
    String? busNumber,
    String? route,
    String? routeDetail,
    String? phoneNumber,
    int? capacity,
  }) {
    return _lifecycle.uploadLocation(
      position: position,
      isOnline: isOnline,
      isTripActive: isTripActive,
      fullName: fullName,
      busNumber: busNumber,
      route: route,
      routeDetail: routeDetail,
      phoneNumber: phoneNumber,
      capacity: capacity,
    );
  }
}
