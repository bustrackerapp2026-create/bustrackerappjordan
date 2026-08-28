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
import '../../../../driver/services/driver_tracking_hub.dart';
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
  final DriverTrackingHub _hub = DriverTrackingHub.instance;

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

  void attachDriverTrackingUi() {
    _hub.mapUiHandler = _onHubPosition;
    trackingServiceState = _hub.state;
  }

  void detachDriverTrackingUi() {
    if (_hub.mapUiHandler == _onHubPosition) {
      _hub.mapUiHandler = null;
    }
    _stopPredictionLoop();
  }

  void _onHubPosition(geo.Position pos) {
    unawaited(
      _applyPosition(
        pos,
        moveCamera: mounted && isMapTabActive && followDriverCamera,
        forceUpload: false,
      ),
    );
  }

  Future<void> preloadDriverMarker() async {
    _cachedDriverMarkerBytes ??= await MapUtils.preloadMarkerImage();
    _cachedDriverMarkerBytes ??= await MapHelpers.createUserMarkerBytes();
  }

  Future<void> updateDriverMarker(
    double lat,
    double lng,
    double bearing, {
    bool force = false,
  }) async {
    if (!mounted || pointAnnotationManager == null) return;
    if (!isMapTabActive && !force) return;

    final now = DateTime.now();
    if (!force && _lastMarkerUpdateAt != null) {
      if (now.difference(_lastMarkerUpdateAt!) < _minMarkerInterval) return;
    }

    if (!force && _lastMarkerLat != null && _lastMarkerLng != null) {
      final moved = _distanceMeters(_lastMarkerLat!, _lastMarkerLng!, lat, lng);
      final bearingDelta = (bearing - _lastMarkerBearing).abs();
      if (moved < _minMarkerMoveMeters && bearingDelta < _minBearingDelta) {
        return;
      }
    }

    if (_markerUpdateInFlight) return;
    _markerUpdateInFlight = true;

    try {
      final point = Point(coordinates: Position(lng, lat));

      if (_driverUserAnnotation != null) {
        _driverUserAnnotation!.geometry = point;
        _driverUserAnnotation!.iconRotate = bearing;
        await pointAnnotationManager?.update(_driverUserAnnotation!);
      } else {
        _cachedDriverMarkerBytes ??= await MapHelpers.createUserMarkerBytes();
        if (_cachedDriverMarkerBytes == null) return;

        _driverUserAnnotation = await pointAnnotationManager?.create(
          PointAnnotationOptions(
            geometry: point,
            image: _cachedDriverMarkerBytes!,
            iconSize: 1.0,
            iconAnchor: IconAnchor.CENTER,
            iconRotate: bearing,
          ),
        );
      }

      _lastMarkerUpdateAt = now;
      _lastMarkerLat = lat;
      _lastMarkerLng = lng;
      _lastMarkerBearing = bearing;
    } catch (e) {
      MapUtils.log('⚠️ علامة السائق: $e', tag: 'DriverLocation');
    } finally {
      _markerUpdateInFlight = false;
    }
  }

  Future<void> goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;

    setState(() => isLoadingDriverLocation = true);

    try {
      final granted =
          await LocationPermissionSheet.ensureDriverBackgroundAccess(context);
      if (!mounted) return;
      if (!granted) {
        MapUtils.showSnackBar(
          context,
          '⚠️ لم يتم منح صلاحية الموقع.',
          isError: true,
        );
        return;
      }

      var gotAnyFix = false;

      final position = await _driverLocationService.locateProgressive(
        quickTimeout: const Duration(seconds: 2),
        preciseTimeout: const Duration(seconds: 6),
        onProgress: (pos, stage) {
          if (!mounted) return;
          gotAnyFix = true;
          final moveCam = stage == LocationFixStage.cached ||
              stage == LocationFixStage.quick;
          unawaited(
            _applyPosition(
              pos,
              moveCamera: moveCam || followDriverCamera,
              forceUpload: stage == LocationFixStage.precise,
            ),
          );
        },
      );

      if (!mounted) return;

      if (position == null && !gotAnyFix) {
        MapUtils.showSnackBar(
          context,
          '⚠️ تعذر الحصول على الموقع.',
          isError: true,
        );
        return;
      }

      if (position != null) {
        await _applyPosition(
          position,
          moveCamera: true,
          forceUpload: true,
        );
      }

      if (_shouldTrackContinuously) {
        await ensureDriverTrackingRunning();
      } else {
        await stopDriverTracking();
      }

      if (!mounted) return;
      MapUtils.showSnackBar(context, '📍 تم تحديد موقعك.');
    } finally {
      if (mounted) setState(() => isLoadingDriverLocation = false);
    }
  }

  Future<void> ensureDriverTrackingRunning() async {
    if (!_shouldTrackContinuously) {
      await stopDriverTracking();
      return;
    }

    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) {
      await stopDriverTracking();
      return;
    }

    final driver = context.read<DriverProvider>();
    _cachedOnline = driver.isOnline;
    _cachedTripActive = driver.isTripActive;

    attachDriverTrackingUi();

    await _hub.requestStart(
      uid: uid,
      profile: _activeProfile,
      isOnline: driver.isOnline,
      isTripActive: driver.isTripActive,
    );
    trackingServiceState = _hub.state;
    if (isMapTabActive) _startPredictionLoop();
  }

  Future<void> stopDriverTracking() async {
    _stopPredictionLoop();
    await _hub.requestStop();
    trackingServiceState = _hub.state;
  }

  void _startPredictionLoop() {
    _predictionTimer?.cancel();
    _predictionTimer = Timer.periodic(_predictionTick, (_) {
      if (!mounted || !isMapTabActive || !_shouldTrackContinuously) return;
      final predicted = _predictor.predictAt(DateTime.now());
      if (predicted == null || predicted.confidence < 0.25) return;

      currentDriverBearing = predicted.headingDeg;
      unawaited(
        updateDriverMarker(
          predicted.latitude,
          predicted.longitude,
          predicted.headingDeg,
        ),
      );

      if (followDriverCamera &&
          predicted.isPredicted &&
          predicted.confidence > 0.45) {
        final now = DateTime.now();
        if (_lastCameraUpdateAt == null ||
            now.difference(_lastCameraUpdateAt!) >= _minCameraInterval) {
          _lastCameraUpdateAt = now;
          unawaited(
            mapboxMap?.setCamera(
                  CameraOptions(
                    center: Point(
                      coordinates: Position(
                        predicted.longitude,
                        predicted.latitude,
                      ),
                    ),
                    zoom: 16,
                    pitch: 0,
                    bearing: 0,
                  ),
                ) ??
                Future<void>.value(),
          );
        }
      }
    });
  }

  void _stopPredictionLoop() {
    _predictionTimer?.cancel();
    _predictionTimer = null;
  }

  Future<void> _applyPosition(
    geo.Position position, {
    required bool moveCamera,
    required bool forceUpload,
  }) async {
    _pendingPosition = position;
    _pendingMoveCamera = _pendingMoveCamera || moveCamera;
    _pendingForceUpload = _pendingForceUpload || forceUpload;

    if (_markerUpdateInFlight) return;

    final pos = _pendingPosition;
    if (pos == null) return;

    final doMove = _pendingMoveCamera;
    final doForce = _pendingForceUpload;
    _pendingPosition = null;
    _pendingMoveCamera = false;
    _pendingForceUpload = false;

    final filtered = _predictor.update(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      speedMs: pos.speed.isFinite ? pos.speed : null,
      headingDeg: pos.heading.isFinite ? pos.heading : null,
      accuracyMeters: pos.accuracy.isFinite ? pos.accuracy : null,
    );

    currentDriverBearing = filtered.headingDeg;
    onDriverPositionSample(pos);

    if (mounted && isMapTabActive && doMove && mapboxMap != null) {
      final now = DateTime.now();
      final canMove = doForce ||
          _lastCameraUpdateAt == null ||
          now.difference(_lastCameraUpdateAt!) >= _minCameraInterval;
      if (canMove) {
        _lastCameraUpdateAt = now;
        try {
          await mapboxMap!.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(
                  filtered.longitude,
                  filtered.latitude,
                ),
              ),
              zoom: 16,
              pitch: 0,
              bearing: 0,
            ),
          );
        } catch (_) {}
      }
    }

    if (mounted) {
      if (isMapTabActive) {
        await updateDriverMarker(
          filtered.latitude,
          filtered.longitude,
          filtered.headingDeg,
          force: doForce,
        );
      }

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final uid = auth.userId;
      final driver = context.read<DriverProvider>();
      _cachedOnline = driver.isOnline;
      _cachedTripActive = driver.isTripActive;
      driver.updatePosition(pos, userId: uid);
      unawaited(_maybeUploadDriverLocation(pos, force: doForce));
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

  Future<void> _maybeUploadDriverLocation(
    geo.Position position, {
    bool force = false,
  }) async {
    if (_isWritingLocation || !mounted) return;

    final driver = context.read<DriverProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;

    if (uid == null || uid.isEmpty) return;
    if (!driver.isBound || driver.boundUserId != uid) return;
    if (!driver.isOnline && !force) return;

    final profile = _activeProfile;
    final now = DateTime.now();

    if (!force && _lastFirestoreLocationWrite != null) {
      if (now.difference(_lastFirestoreLocationWrite!) <
          profile.firestoreMinInterval) {
        return;
      }
    }

    if (!force && _lastUploadedLat != null && _lastUploadedLng != null) {
      final moved = _distanceMeters(
        _lastUploadedLat!,
        _lastUploadedLng!,
        position.latitude,
        position.longitude,
      );
      if (moved < profile.firestoreMinDistanceMeters) return;
    }

    _isWritingLocation = true;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'currentLatitude': position.latitude,
        'currentLongitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isOnline': driver.isOnline,
        'isTripActive': driver.isTripActive,
      });
      final ud = auth.userData;
      await DriverPublicLocationService().publishLocation(
        uid: uid,
        latitude: position.latitude,
        longitude: position.longitude,
        isOnline: driver.isOnline,
        isTripActive: driver.isTripActive,
        heading: position.heading.isFinite ? position.heading : null,
        speed: position.speed.isFinite ? position.speed : null,
        fullName: ud?.fullName,
        busNumber: ud?.busNumber,
        route: ud?.route,
        routeDetail: ud?.routeDetail,
        phoneNumber: ud?.phoneNumber,
        capacity: ud?.capacity,
      );
      _lastFirestoreLocationWrite = now;
      _lastUploadedLat = position.latitude;
      _lastUploadedLng = position.longitude;
      if (mounted) {
        context.read<DriverProvider>().markLocationUploaded(userId: uid);
      }
    } catch (e) {
      MapUtils.log('⚠️ رفع الموقع: $e', tag: 'DriverLocation');
    } finally {
      _isWritingLocation = false;
    }
  }

  double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double d) => d * math.pi / 180;

  void toggleFollowDriverCamera() {
    setState(() => followDriverCamera = !followDriverCamera);
  }

  void recenterDriverCamera() {
    final pos = context.read<DriverProvider>().currentPosition;
    if (pos == null) {
      MapUtils.showSnackBar(context, '⚠️ لا يوجد موقع محدد.', isError: true);
      return;
    }
    flyToFlat(
      latitude: pos.latitude,
      longitude: pos.longitude,
      zoom: 16.5,
    );
  }

  Future<void> refreshDriverTrackingProfile() async {
    if (_shouldTrackContinuously) {
      await ensureDriverTrackingRunning();
    } else {
      await stopDriverTracking();
      _predictor.reset();
      if (followDriverCamera && mounted) {
        setState(() => followDriverCamera = false);
      }
    }
  }

  void onDriverLocationLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_shouldTrackContinuously) {
          unawaited(ensureDriverTrackingRunning());
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // متصل أو في رحلة: نبقي التتبع — لا نوقفه عند الخلفي
        if (!_shouldTrackContinuously) {
          unawaited(stopDriverTracking());
        } else {
          // افصل واجهة الخريطة فقط؛ الـ hub يرفع الموقع وحده
          detachDriverTrackingUi();
        }
        break;
      case AppLifecycleState.detached:
        // لا نوقف هنا إن كان متصلاً — الإيقاف عند «غير متصل» أو تسجيل الخروج
        detachDriverTrackingUi();
        break;
    }
  }

  /// عند إغلاق تبويب الخريطة فقط — لا يوقف تتبع الخلفية.
  void disposeDriverLocation() {
    detachDriverTrackingUi();
    _stopPredictionLoop();
    _predictor.reset();
    _driverUserAnnotation = null;
    _pendingPosition = null;
  }
}
