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

/// مكسين موقع السائق موفّر للبطارية والبيانات.
/// - دقة/مسافة حسب حالة الرحلة
/// - الكاميرا لا تتبع إلا عند تفعيل المتابعة أو زر موقعي
/// - رفع الموقع لـ Firestore بحد أدنى زمني/مسافي
mixin DriverLocationMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  PointAnnotation? _driverUserAnnotation;
  Uint8List? _cachedDriverMarkerBytes;
  StreamSubscription<geo.Position>? _driverLocationSubscription;
  final LocationService _driverLocationService = LocationService();

  bool isLoadingDriverLocation = false;
  double currentDriverBearing = 0.0;

  /// عند true تتحرك الكاميرا مع السائق (مثل أوبر أثناء الرحلة)
  bool followDriverCamera = false;

  DateTime? _lastFirestoreLocationWrite;
  double? _lastUploadedLat;
  double? _lastUploadedLng;
  bool _isWritingLocation = false;

  LocationService get locationService => _driverLocationService;

  LocationTrackingProfile get _activeProfile {
    final driver = context.read<DriverProvider>();
    if (driver.isTripActive) return LocationTrackingProfile.driverTrip;
    return LocationTrackingProfile.driverIdle;
  }

  Future<void> preloadDriverMarker() async {
    _cachedDriverMarkerBytes = await MapUtils.preloadMarkerImage();
  }

  Future<void> updateDriverMarker(
    double lat,
    double lng,
    double bearing,
  ) async {
    if (pointAnnotationManager == null) return;

    final point = Point(coordinates: Position(lng, lat));

    if (_driverUserAnnotation != null) {
      _driverUserAnnotation!.geometry = point;
      _driverUserAnnotation!.iconRotate = bearing;
      await pointAnnotationManager?.update(_driverUserAnnotation!);
      return;
    }

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
    _driverLocationSubscription?.cancel();

    final profile = _activeProfile;
    _driverLocationSubscription = _driverLocationService
        .getPositionStreamForProfile(profile)
        .listen((pos) {
      if (!mounted) return;
      _applyPosition(
        pos,
        moveCamera: followDriverCamera,
        forceUpload: false,
      );
    }, onError: (e) {
      MapUtils.log('⚠️ stream موقع السائق: $e', tag: 'DriverLocation');
    });
  }

  Future<void> _applyPosition(
    geo.Position position, {
    required bool moveCamera,
    required bool forceUpload,
  }) async {
    double bearing = position.heading;
    if (bearing == 0.0 && position.speed > 0) {
      bearing = currentDriverBearing;
    }

    if (mounted && (currentDriverBearing - bearing).abs() > 1) {
      setState(() => currentDriverBearing = bearing);
    } else {
      currentDriverBearing = bearing;
    }

    if (moveCamera) {
      mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 16,
          pitch: 0,
          bearing: 0,
        ),
      );
    }

    await updateDriverMarker(
      position.latitude,
      position.longitude,
      bearing,
    );

    if (!mounted) return;
    context.read<DriverProvider>().updatePosition(position);

    await _maybeUploadDriverLocation(
      position,
      force: forceUpload,
    );
  }

  Future<void> _maybeUploadDriverLocation(
    geo.Position position, {
    bool force = false,
  }) async {
    if (_isWritingLocation) return;
    if (!mounted) return;

    final driver = context.read<DriverProvider>();
    // لا نرفع للسيرفر إن لم يكن متاحاً (توفير بيانات)
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

    if (!force &&
        _lastUploadedLat != null &&
        _lastUploadedLng != null) {
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

  /// يُستدعى عند تغيّر حالة الرحلة لإعادة ضبط ملف التتبع
  Future<void> refreshDriverTrackingProfile() async {
    if (_driverLocationSubscription == null) return;
    await _restartLocationStream();
  }

  void onDriverLocationLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLoadingDriverLocation) {
      goToMyLocation();
    }
    // في الخلفية نوقف التتبع المحلي لتوفير البطارية
    // (تتبع الخلفية الكامل يحتاج Foreground Service لاحقاً أثناء الرحلة)
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _driverLocationSubscription?.cancel();
      _driverLocationSubscription = null;
    }
  }

  void disposeDriverLocation() {
    _driverLocationSubscription?.cancel();
    _driverUserAnnotation = null;
  }
}
