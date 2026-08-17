import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../core/location/tracking_profile.dart';
import '../../services/driver_public_location_service.dart';

/// دورة حياة تتبّع موقع السائق: تشغيل/إيقاف/heartbeat + رفع Firestore.
class DriverTrackingLifecycle {
  DriverTrackingLifecycle();

  final DriverPublicLocationService _public = DriverPublicLocationService();

  StreamSubscription<geo.Position>? _positionSub;
  Timer? _heartbeat;
  Timer? _startDebounce;
  bool _disposed = false;
  bool _wantRunning = false;
  bool _starting = false;
  String? _boundUid;
  TrackingProfile? _activeProfile;

  Future<void> _chain = Future.value();

  void Function(geo.Position position)? onPosition;
  void Function()? onStateChanged;

  bool get isRunning => _positionSub != null;

  Future<T> _enqueue<T>(Future<T> Function() job) {
    final c = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        final r = await job();
        if (!c.isCompleted) c.complete(r);
      } catch (e, st) {
        if (!c.isCompleted) c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<void> start({
    required String uid,
    required TrackingProfile profile,
  }) {
    _wantRunning = true;
    _boundUid = uid;
    _activeProfile = profile;
    _startDebounce?.cancel();
    final c = Completer<void>();
    _startDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(
        _enqueue(() => _startInternal(uid: uid, profile: profile)).then((_) {
          if (!c.isCompleted) c.complete();
        }).catchError((e, st) {
          if (!c.isCompleted) c.completeError(e, st);
        }),
      );
    });
    return c.future;
  }

  Future<void> stop() {
    _wantRunning = false;
    _startDebounce?.cancel();
    return _enqueue(_stopInternal);
  }

  Future<void> _startInternal({
    required String uid,
    required TrackingProfile profile,
  }) async {
    if (_disposed || !_wantRunning) return;
    if (_starting) return;
    _starting = true;
    try {
      await _stopInternal();
      if (_disposed || !_wantRunning) return;

      final settings = geo.LocationSettings(
        accuracy: profile.accuracy,
        distanceFilter: profile.distanceFilterMeters,
      );

      _positionSub = geo.Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (pos) {
          if (_disposed) return;
          onPosition?.call(pos);
        },
        onError: (e) {
          debugPrint('🛰️ position stream error: $e');
        },
      );

      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_disposed || !_wantRunning) return;
        if (_positionSub == null) return;
        // stream still subscribed — nothing extra required
      });

      onStateChanged?.call();
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopInternal() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    onStateChanged?.call();
  }

  /// رفع موقع إلى users (خاص) + driverPublic (عام).
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
  }) async {
    final uid = _boundUid;
    if (uid == null || uid.isEmpty) return;
    if (!isOnline && !isTripActive) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'currentLatitude': position.latitude,
        'currentLongitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isOnline': isOnline,
        'isTripActive': isTripActive,
      });

      await _public.publishLocation(
        uid: uid,
        latitude: position.latitude,
        longitude: position.longitude,
        isOnline: isOnline,
        isTripActive: isTripActive,
        heading: position.heading.isFinite ? position.heading : null,
        speed: position.speed.isFinite ? position.speed : null,
        fullName: fullName,
        busNumber: busNumber,
        route: route,
        routeDetail: routeDetail,
        phoneNumber: phoneNumber,
        capacity: capacity,
      );
    } catch (e) {
      debugPrint('🛰️ upload failed: $e');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _wantRunning = false;
    _startDebounce?.cancel();
    _heartbeat?.cancel();
    await _enqueue(_stopInternal);
    onPosition = null;
    onStateChanged = null;
  }
}
