import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/location/location_permission_sheet.dart';
import '../../../../core/location/location_predictor.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../driver/providers/driver_provider.dart';
import '../../../../driver/services/driver_tracking_lifecycle.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../../../services/location_service.dart';
import '../../../../services/driver_public_location_service.dart';

mixin DriverLocationMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  PointAnnotation? _driverUserAnnotation;
  Uint8List? _cachedDriverMarkerBytes;
  final LocationService _driverLocationService = LocationService();
  final LocationPredictor _predictor = LocationPredictor();

  late final DriverTrackingLifecycle _trackingLifecycle =
      DriverTrackingLifecycle(locationService: _driverLocationService)
        ..onPosition = _onLifecyclePosition
        ..onStateChanged = _onTrackingStateChanged;

  Timer? _predictionTimer;

  bool isLoadingDriverLocation = false;
  double currentDriverBearing = 0.0;
  bool followDriverCamera = false;

  DriverTrackingState trackingServiceState = DriverTrackingState.stopped;

  bool _cachedOnline = false;
  bool _cachedTripActive = false;

  DateTime? _lastFirestoreLocationWrite;
  double? _lastUploadedLat;
  double? _lastUploadedLng;
  bool _isWritingLocation = false;

  DateTime? _lastMarkerUpdateAt;
  DateTime? _lastCameraUpdateAt;
  double? _lastMarkerLat;
  double? _lastMarkerLng;
  double _lastMarkerBearing = 0;
  bool _markerUpdateInFlight = false;
  geo.Position? _pendingPosition;
  bool _pendingMoveCamera = false;
  bool _pendingForceUpload = false;

  static const Duration _minMarkerInterval = Duration(milliseconds: 180);
  static const Duration _minCameraInterval = Duration(milliseconds: 400);
  static const double _minMarkerMoveMeters = 2.5;
  static const double _minBearingDelta = 4.0;
  static const Duration _predictionTick = Duration(milliseconds: 350);

  LocationService get locationService => _driverLocationService;

  void onDriverPositionSample(geo.Position position) {}

  bool get isMapTabActive => true;

  void pauseMapUiUpdates() {
    _stopPredictionLoop();
    followDriverCamera = false;
    _pendingMoveCamera = false;
  }

  bool get _shouldTrackContinuously {
    if (!mounted) return _cachedOnline || _cachedTripActive;
    final driver = context.read<DriverProvider>();
    final auth = context.read<AuthProvider>();
    if (!driver.isBound || driver.boundUserId != auth.userId) return false;
    _cachedOnline = driver.isOnline;
    _cachedTripActive = driver.isTripActive;
    return driver.isOnline || driver.isTripActive;
  }

  LocationTrackingProfile get _activeProfile {
    if (!mounted) {
      return _cachedTripActive
          ? LocationTrackingProfile.driverTrip
          : LocationTrackingProfile.driverIdle;
    }
    final driver = context.read<DriverProvider>();
    _cachedOnline = driver.isOnline;
    _cachedTripActive = driver.isTripActive;
    if (driver.isTripActive) return LocationTrackingProfile.driverTrip;
    return LocationTrackingProfile.driverIdle;
  }

  void _onTrackingStateChanged(DriverTrackingState state) {
    if (!mounted) return;
    setState(() => trackingServiceState = state);
  }

  void _onLifecyclePosition(geo.Position position) {
    if (!mounted) return;
    unawaited(_applyPosition(position, moveCamera: followDriverCamera));
  }

  Future<void> ensureDriverTrackingRunning() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) return;
    if (!_shouldTrackContinuously) return;
    await _trackingLifecycle.requestStart(uid: uid, profile: _activeProfile);
  }

  Future<void> stopDriverTracking() async {
    await _trackingLifecycle.requestStop();
  }

  Future<void> goToDriverLocation({bool forceUpload = false}) async {
    if (!mounted) return;
    setState(() => isLoadingDriverLocation = true);
    try {
      final granted = await LocationPermissionSheet.ensurePermission(context);
      if (!mounted) return;
      if (!granted) {
        MapUtils.showSnackBar(context, '⚠️ لم يتم منح صلاحية الموقع', isError: true);
        return;
      }
      final pos = await _driverLocationService.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        MapUtils.showSnackBar(context, '⚠️ تعذر الحصول على الموقع', isError: true);
        return;
      }
      await _applyPosition(pos, moveCamera: true, forceUpload: forceUpload);
    } catch (e) {
      if (mounted) {
        MapUtils.showSnackBar(context, '❌ خطأ في تحديد الموقع', isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoadingDriverLocation = false);
    }
  }

  Future<void> _applyPosition(
    geo.Position pos, {
    required bool moveCamera,
    bool forceUpload = false,
  }) async {
    if (!mounted) return;

    if (_markerUpdateInFlight) {
      _pendingPosition = pos;
      _pendingMoveCamera = moveCamera || _pendingMoveCamera;
      _pendingForceUpload = forceUpload || _pendingForceUpload;
      return;
    }
    _markerUpdateInFlight = true;
    _pendingPosition = null;
    final doForce = forceUpload;
    _pendingForceUpload = false;
    _pendingMoveCamera = false;

    try {
      onDriverPositionSample(pos);
      _predictor.addSample(pos);
      _ensurePredictionLoop();

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final uid = auth.userId;
      final driver = context.read<DriverProvider>();
      _cachedOnline = driver.isOnline;
      _cachedTripActive = driver.isTripActive;
      driver.updatePosition(pos, userId: uid);
      unawaited(_maybeUploadDriverLocation(pos, force: doForce));
    } else if (_cachedOnline || _cachedTripActive) {
      unawaited(
        _trackingLifecycle.uploadLocation(
          position: pos,
          isOnline: _cachedOnline,
          isTripActive: _cachedTripActive,
        ),
      );
    }

    if (_pendingPosition != null && mounted) {
      unawaited(
        _applyPosition(
          _pendingPosition!,
          moveCamera: _pendingMoveCamera,
          forceUpload: _pendingForceUpload,
        ),
      );
    }
  }

  // NOTE: truncated restore - WILL BE FIXED
  void disposeDriverLocation() {
    _stopPredictionLoop();
    unawaited(_trackingLifecycle.dispose());
    _predictor.reset();
    _driverUserAnnotation = null;
    _pendingPosition = null;
  }

  void _stopPredictionLoop() {
    _predictionTimer?.cancel();
    _predictionTimer = null;
  }

  void _ensurePredictionLoop() {}

  Future<void> _maybeUploadDriverLocation(geo.Position position, {bool force = false}) async {}
}
