import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../driver/providers/driver_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../../../services/location_service.dart';

/// مكسين موقع السائق — أداء عالٍ:
/// - لا setState عند كل نبضة GPS (تحديث العلامة/الكاميرا فقط)
/// - تخفيف تحديثات العلامة والكاميرا
/// - رفع Firestore بحدود زمنية/مسافية
mixin DriverLocationMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  PointAnnotation? _driverUserAnnotation;
  Uint8List? _cachedDriverMarkerBytes;
  StreamSubscription<geo.Position>? _driverLocationSubscription;
  final LocationService _driverLocationService = LocationService();

  bool isLoadingDriverLocation = false;
  double currentDriverBearing = 0.0;

  /// عند true تتحرك الكاميرا مع السائق
  bool followDriverCamera = false;

  DateTime? _lastFirestoreLocationWrite;
  double? _lastUploadedLat;
  double? _lastUploadedLng;
  bool _isWritingLocation = false;

  // تخفيف تحديثات الطبقة الرسومية
  DateTime? _lastMarkerUpdateAt;
  DateTime? _lastCameraUpdateAt;
  double? _lastMarkerLat;
  double? _lastMarkerLng;
  double _lastMarkerBearing = 0;
  bool _markerUpdateInFlight = false;
  geo.Position? _pendingPosition;
  bool _pendingMoveCamera = false;
  bool _pendingForceUpload = false;

  static const Duration _minMarkerInterval = Duration(milliseconds: 120);
  static const Duration _minCameraInterval = Duration(milliseconds: 250);
  static const double _minMarkerMoveMeters = 2.0;
  static const double _minBearingDelta = 3.0;

  LocationService get locationService => _driverLocationService;

  LocationTrackingProfile get _activeProfile {
    final driver = context.read<DriverProvider>();
    if (driver.isTripActive) return LocationTrackingProfile.driverTrip;
    return LocationTrackingProfile.driverIdle;
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
    if (pointAnnotationManager == null) return;

    final now = DateTime.now();
    if (!force && _lastMarkerUpdateAt != null) {
      if (now.difference(_lastMarkerUpdateAt!) < _minMarkerInterval) {
        return;
      }
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
      MapUtils.log('⚠️ تحديث علامة السائق: $e', tag: 'DriverLocation');
    } finally {
      _markerUpdateInFlight = false;
    }
  }

  Future<void> goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;

    setState(() => isLoadingDriverLocation = true);

    try {
      if (!await _driverLocationService.checkAndRequestPermission()) {
        if (!mounted) return;
        MapUtils.showSnackBar(
          context,
          '⚠️ يرجى تفعيل خدمة الموقع.',
          isError: true,
        );
        return;
      }
      if (!mounted) return;

      await _restartLocationStream();

      final position = await _driverLocationService.getCurrentPosition(
        preferHighAccuracy: true,
      );
      if (!mounted) return;

      if (position == null) {
        MapUtils.showSnackBar(
          context,
          '⚠️ تعذر الحصول على الموقع.',
          isError: true,
        );
        return;
      }

      await _applyPosition(position, moveCamera: true, forceUpload: true);

      if (!mounted) return;
      MapUtils.showSnackBar(context, '📍 تم تحديد موقعك.');
    } finally {
      if (mounted) setState(() => isLoadingDriverLocation = false);
    }
  }

  Future<void> _restartLocationStream() async {
    await _driverLocationSubscription?.cancel();

    final profile = _activeProfile;
    _driverLocationSubscription = _driverLocationService
        .getPositionStreamForProfile(profile)
        .listen(
      (pos) {
        if (!mounted) return;
        // لا ننتظر — نجدول التحديث بدون حظر الـ stream
        unawaited(
          _applyPosition(
            pos,
            moveCamera: followDriverCamera,
            forceUpload: false,
          ),
        );
      },
      onError: (e) {
        MapUtils.log('⚠️ stream موقع السائق: $e', tag: 'DriverLocation');
      },
    );
  }

  Future<void> _applyPosition(
    geo.Position position, {
    required bool moveCamera,
    required bool forceUpload,
  }) async {
    // دمج التحديثات السريعة: احتفظ بآخر موضع فقط
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

    double bearing = pos.heading;
    if ((bearing == 0.0) && pos.speed > 0.5) {
      bearing = currentDriverBearing;
    }
    // بدون setState — الاتجاه يخص العلامة فقط
    currentDriverBearing = bearing;

    // كاميرا مخفّفة
    if (doMove && mapboxMap != null) {
      final now = DateTime.now();
      final canMoveCamera = doForce ||
          _lastCameraUpdateAt == null ||
          now.difference(_lastCameraUpdateAt!) >= _minCameraInterval;

      if (canMoveCamera) {
        _lastCameraUpdateAt = now;
        // setCamera أخف من flyTo أثناء التتبع المستمر
        try {
          await mapboxMap!.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(pos.longitude, pos.latitude),
              ),
              zoom: 16,
              pitch: 0,
              bearing: 0,
            ),
          );
        } catch (_) {}
      }
    }

    await updateDriverMarker(
      pos.latitude,
      pos.longitude,
      bearing,
      force: doForce,
    );

    if (!mounted) return;

    // Provider قد يُعلم المستمعين — لا يعتمد على setState هنا
    context.read<DriverProvider>().updatePosition(pos);

    unawaited(_maybeUploadDriverLocation(pos, force: doForce));

    // إن وصل موضع أحدث أثناء التحديث، طبّقه
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
    if (_isWritingLocation) return;
    if (!mounted) return;

    final driver = context.read<DriverProvider>();
    if (!driver.isOnline && !force) return;

    final uid = context.read<AuthProvider>().userId;
    if (uid == null) return;

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
      });
      _lastFirestoreLocationWrite = now;
      _lastUploadedLat = position.latitude;
      _lastUploadedLng = position.longitude;
    } catch (e) {
      MapUtils.log('⚠️ فشل رفع موقع السائق: $e', tag: 'DriverLocation');
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
      MapUtils.showSnackBar(
        context,
        '⚠️ لا يوجد موقع محدد.',
        isError: true,
      );
      return;
    }
    flyToFlat(
      latitude: pos.latitude,
      longitude: pos.longitude,
      zoom: 16.5,
    );
  }

  Future<void> refreshDriverTrackingProfile() async {
    if (_driverLocationSubscription == null) return;
    await _restartLocationStream();
  }

  void onDriverLocationLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // استئناف التتبع إن كان السائق متصلاً أو في رحلة
      if (!mounted) return;
      final driver = context.read<DriverProvider>();
      if (driver.isOnline || driver.isTripActive) {
        unawaited(_restartLocationStream());
      }
      return;
    }

    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _driverLocationSubscription?.cancel();
      _driverLocationSubscription = null;
    }
  }

  void disposeDriverLocation() {
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _driverUserAnnotation = null;
    _pendingPosition = null;
  }
}
