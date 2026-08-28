import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../services/location_service.dart';
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
  String? _uid;

  DriverTrackingState get state => _lifecycle.state;
  bool get isRunning => _lifecycle.isRunning;
  geo.Position? get lastPosition => _lifecycle.lastPosition;

  void _dispatchPosition(geo.Position pos) {
    final ui = mapUiHandler;
    if (ui != null) {
      ui(pos);
      return;
    }
    // لا واجهة خريطة: ارفع الموقع للخادم مباشرة
    if (_wantOnline || _wantTrip) {
      unawaited(
        _lifecycle.uploadLocation(
          position: pos,
          isOnline: _wantOnline,
          isTripActive: _wantTrip,
        ),
      );
    }
  }

  Future<void> requestStart({
    required String uid,
    required LocationTrackingProfile profile,
    required bool isOnline,
    required bool isTripActive,
  }) async {
    _uid = uid;
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
