import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../../../services/location_service.dart';

/// مكسين موقع الراكب: تتبع GPS + ماركر المستخدم + البحث عن الأماكن.
/// ضمن صلاحيات الراكب فقط.
mixin PassengerLocationMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  PointAnnotation? _passengerUserAnnotation;
  Uint8List? _cachedPassengerMarkerBytes;
  StreamSubscription<geo.Position>? _passengerLocationSubscription;
  final LocationService _passengerLocationService = LocationService();

  bool isLoadingPassengerLocation = false;
  double currentPassengerBearing = 0.0;

  LocationService get locationService => _passengerLocationService;

  Future<void> preloadPassengerMarker() async {
    _cachedPassengerMarkerBytes = await MapHelpers.createUserMarkerBytes();
  }

  Future<void> updatePassengerMarker(
    double lat,
    double lng,
    double bearing,
  ) async {
    if (pointAnnotationManager == null) return;

    final point = Point(coordinates: Position(lng, lat));

    if (_passengerUserAnnotation != null) {
      _passengerUserAnnotation!.geometry = point;
      _passengerUserAnnotation!.iconRotate = bearing;
      await pointAnnotationManager?.update(_passengerUserAnnotation!);
      return;
    }

    _cachedPassengerMarkerBytes ??= await MapHelpers.createUserMarkerBytes();
    if (_cachedPassengerMarkerBytes == null) return;

    _passengerUserAnnotation = await pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: point,
        image: _cachedPassengerMarkerBytes!,
        iconSize: 1.0,
        iconAnchor: IconAnchor.CENTER,
        iconRotate: bearing,
      ),
    );
  }

  Future<void> goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;

    setState(() => isLoadingPassengerLocation = true);

    try {
      final hasPermission =
          await _passengerLocationService.checkAndRequestPermission();
      if (!mounted) return;

      if (!hasPermission) {
        final deniedForever =
            await _passengerLocationService.isPermissionDeniedForever();
        if (deniedForever) {
          final shouldOpen = await _showPermissionDialog();
          if (shouldOpen == true) {
            await _passengerLocationService.openAppSettings();
          }
        } else {
          final serviceEnabled =
              await geo.Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            MapUtils.showSnackBar(
              context,
              '⚠️ يرجى تفعيل خدمة الموقع من إعدادات الجهاز.',
              isError: true,
            );
            await _passengerLocationService.openLocationSettings();
          } else {
            MapUtils.showSnackBar(
              context,
              '⚠️ يرجى السماح بصلاحية الموقع.',
              isError: true,
            );
          }
        }
        return;
      }

      _passengerLocationSubscription?.cancel();

      final lastKnown =
          await _passengerLocationService.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        await _moveCameraAndMarker(lastKnown);
      }

      final position = await _passengerLocationService.getCurrentPosition(
        preferHighAccuracy: true,
        timeout: const Duration(seconds: 15),
      );

      if (!mounted) return;

      if (position == null) {
        MapUtils.showSnackBar(
          context,
          '❌ تعذر تحديد موقعك. تأكد من تفعيل GPS والخروج لمكان مفتوح إن أمكن.',
          isError: true,
        );
        return;
      }

      await _moveCameraAndMarker(position);

      _passengerLocationSubscription = _passengerLocationService
          .getPositionStream(distanceFilter: 5)
          .listen((geo.Position pos) {
        if (mounted) {
          _moveCameraAndMarker(pos);
        }
      }, onError: (error) {
        MapUtils.log('خطأ في تحديث الموقع: $error', tag: 'PassengerLocation');
      });

      if (mounted) {
        MapUtils.showSnackBar(context, '📍 تم تحديد موقعك بنجاح.');
      }
    } catch (e) {
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          '❌ تعذر تحديد موقعك. حاول مرة أخرى.',
          isError: true,
        );
        MapUtils.log('خطأ تحديد الموقع: $e', tag: 'PassengerLocation');
      }
    } finally {
      if (mounted) setState(() => isLoadingPassengerLocation = false);
    }
  }

  Future<void> _moveCameraAndMarker(geo.Position position) async {
    double bearing = position.heading;
    if (bearing == 0.0 && position.speed > 0) {
      bearing = currentPassengerBearing;
    }

    if (mounted) {
      setState(() => currentPassengerBearing = bearing);
    }

    await flyToFlat(
      latitude: position.latitude,
      longitude: position.longitude,
      zoom: 15.5,
    );

    await updatePassengerMarker(
      position.latitude,
      position.longitude,
      bearing,
    );
  }

  Future<bool?> _showPermissionDialog() async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تفعيل الموقع'),
        content: const Text(
          'لتحديد موقعك بدقة مثل خرائط جوجل، نحتاج إلى صلاحية الموقع.\n\n'
          'يمكنك السماح عند استخدام التطبيق أو فتح الإعدادات ومنح الصلاحية يدوياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<void> searchPassengerPlace(String query) async {
    if (!mounted) return;
    await MapUtils.searchPlace(
      context,
      mapboxMap,
      query,
      0,
      _passengerLocationService,
    );
  }

  void onPassengerLocationLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLoadingPassengerLocation) {
      goToMyLocation();
    }
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _passengerLocationSubscription?.cancel();
    }
  }

  void disposePassengerLocation() {
    _passengerLocationSubscription?.cancel();
    _passengerUserAnnotation = null;
  }
}
