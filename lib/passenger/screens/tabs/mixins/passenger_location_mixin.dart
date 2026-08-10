import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../../../services/location_service.dart';

mixin PassengerLocationMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  PointAnnotation? _passengerUserAnnotation;
  Uint8List? _cachedPassengerMarkerBytes;
  StreamSubscription<geo.Position>? _passengerLocationSubscription;
  final LocationService _passengerLocationService = LocationService();

  bool isLoadingPassengerLocation = false;
  double currentPassengerBearing = 0.0;
  bool isPassengerTrackingActive = false;

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

  void _safeSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    MapUtils.showSnackBar(context, message, isError: isError);
  }

  /// زر موقعي — عرض فوري ثم تحسين (مثل جوجل ماب)
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
        if (!mounted) return;

        if (deniedForever) {
          final shouldOpen = await _showPermissionDialog();
          if (!mounted) return;
          if (shouldOpen == true) {
            await _passengerLocationService.openAppSettings();
          }
        } else {
          final serviceEnabled =
              await geo.Geolocator.isLocationServiceEnabled();
          if (!mounted) return;

          if (!serviceEnabled) {
            _safeSnack(
              '⚠️ يرجى تفعيل خدمة الموقع من إعدادات الجهاز.',
              isError: true,
            );
            await _passengerLocationService.openLocationSettings();
          } else {
            _safeSnack('⚠️ يرجى السماح بصلاحية الموقع.', isError: true);
          }
        }
        return;
      }

      _passengerLocationSubscription?.cancel();

      var gotAnyFix = false;

      final position = await _passengerLocationService.locateProgressive(
        quickTimeout: const Duration(seconds: 3),
        preciseTimeout: const Duration(seconds: 7),
        onProgress: (pos, stage) {
          if (!mounted) return;
          gotAnyFix = true;
          final moveCam = stage == LocationFixStage.cached ||
              stage == LocationFixStage.quick ||
              stage == LocationFixStage.precise;
          unawaited(_applyPosition(pos, moveCamera: moveCam));
        },
      );

      if (!mounted) return;

      if (position == null && !gotAnyFix) {
        _safeSnack(
          '❌ تعذر تحديد موقعك. تأكد من تفعيل GPS.',
          isError: true,
        );
        return;
      }

      if (position != null) {
        await _applyPosition(position, moveCamera: true);
      }

      if (!mounted) return;

      // تتبع خفيف بعد التثبيت (اختياري للراكب)
      isPassengerTrackingActive = true;
      _passengerLocationSubscription = _passengerLocationService
          .getPositionStreamForProfile(LocationTrackingProfile.passengerBrowse)
          .listen((geo.Position pos) {
        if (mounted) {
          unawaited(_applyPosition(pos, moveCamera: false));
        }
      }, onError: (error) {
        MapUtils.log('خطأ في تحديث الموقع: $error', tag: 'PassengerLocation');
      });

      _safeSnack('📍 تم تحديد موقعك بنجاح.');
    } catch (e) {
      _safeSnack('❌ تعذر تحديد موقعك. حاول مرة أخرى.', isError: true);
      MapUtils.log('خطأ تحديد الموقع: $e', tag: 'PassengerLocation');
    } finally {
      if (mounted) setState(() => isLoadingPassengerLocation = false);
    }
  }

  Future<void> _applyPosition(
    geo.Position position, {
    required bool moveCamera,
  }) async {
    double bearing = position.heading;
    if (bearing == 0.0 && position.speed > 0) {
      bearing = currentPassengerBearing;
    }
    currentPassengerBearing = bearing;

    if (moveCamera) {
      // setCamera أسرع من flyTo عند التحديثات المتتالية
      try {
        await mapboxMap?.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(position.longitude, position.latitude),
            ),
            zoom: 15.5,
            pitch: 0,
            bearing: 0,
          ),
        );
      } catch (_) {
        await flyToFlat(
          latitude: position.latitude,
          longitude: position.longitude,
          zoom: 15.5,
        );
      }
    }

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
          'لتحديد موقعك نحتاج إلى صلاحية الموقع.',
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

  void stopPassengerTracking() {
    _passengerLocationSubscription?.cancel();
    _passengerLocationSubscription = null;
    isPassengerTrackingActive = false;
  }

  void onPassengerLocationLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isLoadingPassengerLocation) {
      goToMyLocation();
    }
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      stopPassengerTracking();
    }
  }

  void disposePassengerLocation() {
    stopPassengerTracking();
    _passengerUserAnnotation = null;
  }
}
