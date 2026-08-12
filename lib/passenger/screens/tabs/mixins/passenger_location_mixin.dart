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

  DateTime? _lastMarkerAt;
  double? _lastMarkerLat;
  double? _lastMarkerLng;
  bool _markerBusy = false;

  static const Duration _minMarkerInterval = Duration(milliseconds: 220);
  static const double _minMoveDeg = 0.00003; // ≈ 3م

  LocationService get locationService => _passengerLocationService;

  Future<void> preloadPassengerMarker() async {
    _cachedPassengerMarkerBytes = await MapHelpers.createUserMarkerBytes();
  }

  Future<void> updatePassengerMarker(
    double lat,
    double lng,
    double bearing, {
    bool force = false,
  }) async {
    if (pointAnnotationManager == null) return;

    final now = DateTime.now();
    if (!force && _lastMarkerAt != null) {
      if (now.difference(_lastMarkerAt!) < _minMarkerInterval) return;
    }
    if (!force && _lastMarkerLat != null && _lastMarkerLng != null) {
      final dLat = (lat - _lastMarkerLat!).abs();
      final dLng = (lng - _lastMarkerLng!).abs();
      if (dLat < _minMoveDeg && dLng < _minMoveDeg) return;
    }
    if (_markerBusy) return;
    _markerBusy = true;

    try {
      final point = Point(coordinates: Position(lng, lat));

      if (_passengerUserAnnotation != null) {
        _passengerUserAnnotation!.geometry = point;
        _passengerUserAnnotation!.iconRotate = bearing;
        await pointAnnotationManager?.update(_passengerUserAnnotation!);
      } else {
        _cachedPassengerMarkerBytes ??=
            await MapHelpers.createUserMarkerBytes();
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

      _lastMarkerAt = now;
      _lastMarkerLat = lat;
      _lastMarkerLng = lng;
    } catch (_) {
    } finally {
      _markerBusy = false;
    }
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
          unawaited(_applyPosition(pos, moveCamera: moveCam, force: true));
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
        await _applyPosition(position, moveCamera: true, force: true);
      }

      if (!mounted) return;

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
    bool force = false,
  }) async {
    double bearing = position.heading;
    if (bearing == 0.0 && position.speed > 0) {
      bearing = currentPassengerBearing;
    }
    currentPassengerBearing = bearing;

    if (moveCamera) {
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
      force: force,
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
