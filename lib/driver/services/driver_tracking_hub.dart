import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../services/location_service.dart';
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

  static const Duration _vehicleTripLocationInterval =
      Duration(seconds: 5);

  DriverTrackingState get state => _lifecycle.state;
  bool get isRunning => _lifecycle.isRunning;
  geo.Position? get lastPosition => _lifecycle.lastPosition;

  /// يربط الـHub بمعرف VehicleTrip النشطة حتى يستمر التحديث
  /// حتى لو أُغلقت واجهة الخريطة أو تغيرت الشاشة.
  void setActiveVehicleTrip(String? tripId) {
    final normalized = tripId?.trim();
    _vehicleTripFlushTimer?.cancel();
    _vehicleTripFlushTimer = null;

    if (normalized == null || normalized.isEmpty) {
      _activeVehicleTripId = null;
      _lastVehicleTripLocationWriteAt = null;
      _pendingVehicleTripPosition = null;
      return;
    }

    if (_activeVehicleTripId == normalized) return;

    _activeVehicleTripId = normalized;
    _lastVehicleTripLocationWriteAt = null;
    _pendingVehicleTripPosition = null;
  }

  void clearActiveVehicleTrip() {
    setActiveVehicleTrip(null);
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
      if (_activeVehicleTripId != tripId ||
          _pendingVehicleTripPosition == null) {
        return;
      }

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
