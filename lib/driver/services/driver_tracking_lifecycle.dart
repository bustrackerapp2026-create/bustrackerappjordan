import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../services/driver_public_location_service.dart';
import '../../services/location_service.dart';

enum DriverTrackingState {
  stopped,
  starting,
  running,
  stopping,
}

class DriverTrackingLifecycle {
  DriverTrackingLifecycle({
    LocationService? locationService,
  }) : _location = locationService ?? LocationService();

  final LocationService _location;
  final DriverPublicLocationService _public = DriverPublicLocationService();

  StreamSubscription<geo.Position>? _sub;
  Timer? _heartbeat;
  Timer? _startDebounce;

  DriverTrackingState _state = DriverTrackingState.stopped;
  LocationTrackingProfile? _activeProfile;
  String? _boundUid;
  bool _wantRunning = false;
  bool _disposed = false;

  geo.Position? lastPosition;
  DateTime? lastPositionAt;

  Future<void> _chain = Future<void>.value();

  void Function(geo.Position position)? onPosition;
  void Function(DriverTrackingState state)? onStateChanged;

  DriverTrackingState get state => _state;
  bool get isRunning => _state == DriverTrackingState.running;
  LocationTrackingProfile? get activeProfile => _activeProfile;
  String? get boundUid => _boundUid;

  void _setState(DriverTrackingState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged?.call(next);
    if (kDebugMode) {
      debugPrint('🛰️ DriverTrackingLifecycle → $next (profile=$_activeProfile)');
    }
  }

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

  Future<void> requestStart({
    required String uid,
    required LocationTrackingProfile profile,
  }) {
    if (_disposed) return Future.value();
    _wantRunning = true;
    _boundUid = uid;
    return _enqueue(() => _startInternal(uid: uid, profile: profile));
  }

  Future<void> requestStop() {
    _wantRunning = false;
    _startDebounce?.cancel();
    return _enqueue(_stopInternal);
  }

  Future<void> _startInternal({
    required String uid,
    required LocationTrackingProfile profile,
  }) async {
    if (_disposed || !_wantRunning) return;

    if (_state == DriverTrackingState.running &&
        _activeProfile == profile &&
        _boundUid == uid &&
        _sub != null) {
      _armHeartbeat();
      return;
    }

    _setState(DriverTrackingState.starting);
    await _cancelStreamOnly();

    final permission = await _location.ensureBackgroundLocationPermission();
    if (!_wantRunning || _disposed) {
      _setState(DriverTrackingState.stopped);
      return;
    }

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      debugPrint('🛰️ tracking: no permission');
      _setState(DriverTrackingState.stopped);
      return;
    }

    _boundUid = uid;
    _activeProfile = profile;

    try {
      _sub = _location.getPositionStreamForProfile(profile).listen(
        (pos) {
          lastPosition = pos;
          lastPositionAt = DateTime.now();
          onPosition?.call(pos);
        },
        onError: (e) {
          debugPrint('🛰️ stream error: $e');
          if (_wantRunning && !_disposed) {
            unawaited(
              _enqueue(() async {
                await Future<void>.delayed(const Duration(seconds: 2));
                if (_wantRunning && !_disposed && _boundUid != null) {
                  await _startInternal(
                    uid: _boundUid!,
                    profile: _activeProfile ?? profile,
                  );
                }
              }),
            );
          }
        },
        onDone: () {
          debugPrint('🛰️ stream done');
          if (_wantRunning && !_disposed && _boundUid != null) {
            unawaited(
              _enqueue(() async {
                await Future<void>.delayed(const Duration(seconds: 1));
                if (_wantRunning && !_disposed && _boundUid != null) {
                  await _startInternal(
                    uid: _boundUid!,
                    profile: _activeProfile ?? profile,
                  );
                }
              }),
            );
          }
        },
        cancelOnError: false,
      );

      _setState(DriverTrackingState.running);
      _armHeartbeat();
    } catch (e) {
      debugPrint('🛰️ start failed: $e');
      await _cancelStreamOnly();
      _setState(DriverTrackingState.stopped);
    }
  }

  Future<void> _stopInternal() async {
    if (_state == DriverTrackingState.stopped && _sub == null) return;
    _setState(DriverTrackingState.stopping);
    _heartbeat?.cancel();
    _heartbeat = null;
    await _cancelStreamOnly();
    _activeProfile = null;
    _setState(DriverTrackingState.stopped);
  }

  Future<void> _cancelStreamOnly() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
  }

  void _armHeartbeat() {
    _heartbeat?.cancel();
    final timeout = _activeProfile == LocationTrackingProfile.driverTrip
        ? const Duration(seconds: 45)
        : const Duration(seconds: 90);

    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_disposed || !_wantRunning) return;
      if (_state != DriverTrackingState.running) return;

      final last = lastPositionAt;
      if (last == null) return;
      if (DateTime.now().difference(last) < timeout) return;

      debugPrint('🛰️ heartbeat: stream stale → restart');
      final uid = _boundUid;
      final profile = _activeProfile;
      if (uid == null || profile == null) return;
      unawaited(
        _enqueue(() => _startInternal(uid: uid, profile: profile)),
      );
    });
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
