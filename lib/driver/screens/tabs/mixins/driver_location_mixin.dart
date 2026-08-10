import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../driver/providers/driver_provider.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../../../services/location_service.dart';

/// مكسين موقع السائق: تتبع GPS + ماركر المستخدم + إعادة التمركز.
/// ضمن صلاحيات السائق فقط — بدون إدارة سائقين/ركاب/مسارات الأدمن.
mixin DriverLocationMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  PointAnnotation? _driverUserAnnotation;
  Uint8List? _cachedDriverMarkerBytes;
  StreamSubscription<geo.Position>? _driverLocationSubscription;
  final LocationService _driverLocationService = LocationService();

  bool isLoadingDriverLocation = false;
  double currentDriverBearing = 0.0;

  LocationService get locationService => _driverLocationService;

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

      _driverLocationSubscription?.cancel();

      final position = await _driverLocationService.getCurrentPosition();
      if (!mounted) return;

      if (position == null) {
        MapUtils.showSnackBar(
          context,
          '⚠️ تعذر الحصول على الموقع.',
          isError: true,
        );
        return;
      }

      double bearing = position.heading;
      if (bearing == 0.0 && position.speed > 0) {
        bearing = currentDriverBearing;
      }
      setState(() => currentDriverBearing = bearing);

      await flyToFlat(
        latitude: position.latitude,
        longitude: position.longitude,
        zoom: 16,
      );
      await updateDriverMarker(
        position.latitude,
        position.longitude,
        bearing,
      );

      if (!mounted) return;
      context.read<DriverProvider>().updatePosition(position);

      _driverLocationSubscription = _driverLocationService
          .getPositionStream(distanceFilter: 5)
          .listen((pos) {
        if (!mounted) return;

        double newBearing = pos.heading;
        if (newBearing == 0.0 && pos.speed > 0) {
          newBearing = currentDriverBearing;
        }
        setState(() => currentDriverBearing = newBearing);

        mapboxMap?.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(pos.longitude, pos.latitude)),
            zoom: 16,
            pitch: 0,
            bearing: 0,
          ),
        );

        updateDriverMarker(pos.latitude, pos.longitude, newBearing);
        context.read<DriverProvider>().updatePosition(pos);
      });

      if (!mounted) return;
      MapUtils.showSnackBar(context, '📍 تم تحديد موقعك.');
    } finally {
      if (mounted) setState(() => isLoadingDriverLocation = false);
    }
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

  void onDriverLocationLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLoadingDriverLocation) {
      goToMyLocation();
    }
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _driverLocationSubscription?.cancel();
    }
  }

  void disposeDriverLocation() {
    _driverLocationSubscription?.cancel();
    _driverUserAnnotation = null;
  }
}
