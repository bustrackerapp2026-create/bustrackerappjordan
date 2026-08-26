import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/location/location_fix_tracer.dart';
import '../../../../core/location/location_permission_sheet.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../../../services/location_service.dart';

mixin PassengerLocationMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  PointAnnotation? _passengerUserAnnotation;
  Uint8List? _cachedPassengerMarkerBytes;
  StreamSubscription<geo.Position>? _passengerLocationSubscription;
  final LocationService _passengerLocationService = LocationService();
  final LocationFixTracer _fixTracer = LocationFixTracer(role: 'passenger');

  CircleAnnotationManager? _accuracyCircleManager;
  CircleAnnotation? _accuracyCircle;

  bool isLoadingPassengerLocation = false;
  double currentPassengerBearing = 0.0;
  bool isPassengerTrackingActive = false;

  /// آخر موقع معروف للراكب (لأقرب باص)
  double? lastPassengerLat;
  double? lastPassengerLng;

  /// آخر دقة أفقية بالمتر (إن وُجدت)
  double? lastPassengerAccuracyMeters;

  DateTime? _lastMarkerAt;
  double? _lastMarkerLat;
  double? _lastMarkerLng;
  bool _markerBusy = false;

  /// يمنع طلب موقع ثانٍ أثناء جريان الأول (single-flight).
  bool _locateInFlight = false;

  /// بعد العودة من إعدادات GPS: إعادة محاولة واحدة بهدوء إن لم نحصل على موقع.
  bool _retryLocateOnResume = false;

  LocationFixStage? _lastAnnouncedStage;
  DateTime? _lastStageSnackAt;

  static const Duration _minMarkerInterval = Duration(milliseconds: 220);
  static const double _minMoveDeg = 0.00003;

  LocationService get locationService => _passengerLocationService;

  bool get hasPassengerLocation =>
      lastPassengerLat != null && lastPassengerLng != null;

  Future<void> preloadPassengerMarker() async {
    _cachedPassengerMarkerBytes = await MapHelpers.createUserMarkerBytes();
  }

  Future<void> _ensureAccuracyCircleManager() async {
    if (_accuracyCircleManager != null || mapboxMap == null) return;
    try {
      _accuracyCircleManager =
          await mapboxMap!.annotations.createCircleAnnotationManager();
    } catch (e) {
      MapUtils.log('accuracy circle manager: $e', tag: 'PassengerLocation');
    }
  }

  /// نصف قطر الدائرة بالبكسل تقريباً من دقة بالمتر عند مستوى الزوم الحالي.
  Future<double> _metersToCircleRadiusPx(double meters, double latitude) async {
    var zoom = 15.5;
    try {
      final state = await mapboxMap?.getCameraState();
      if (state != null) zoom = state.zoom;
    } catch (_) {}
    final metersPerPixel = 156543.03392 *
        math.cos(latitude * math.pi / 180.0) /
        math.pow(2.0, zoom);
    if (metersPerPixel <= 0) return 18;
    final px = meters / metersPerPixel;
    return px.clamp(12.0, 120.0);
  }

  Future<void> _updateAccuracyCircle({
    required double lat,
    required double lng,
    required double accuracyMeters,
  }) async {
    if (mapboxMap == null) return;
    await _ensureAccuracyCircleManager();
    final manager = _accuracyCircleManager;
    if (manager == null) return;

    final radiusPx = await _metersToCircleRadiusPx(accuracyMeters, lat);
    final point = Point(coordinates: Position(lng, lat));
    const fill = 0x402563EB;
    const stroke = 0x992563EB;

    try {
      if (_accuracyCircle != null) {
        _accuracyCircle!.geometry = point;
        _accuracyCircle!.circleRadius = radiusPx;
        _accuracyCircle!.circleColor = fill;
        _accuracyCircle!.circleStrokeColor = stroke;
        _accuracyCircle!.circleStrokeWidth = 1.2;
        await manager.update(_accuracyCircle!);
      } else {
        _accuracyCircle = await manager.create(
          CircleAnnotationOptions(
            geometry: point,
            circleRadius: radiusPx,
            circleColor: fill,
            circleStrokeColor: stroke,
            circleStrokeWidth: 1.2,
            circleOpacity: 1.0,
          ),
        );
      }
    } catch (e) {
      MapUtils.log('update accuracy circle: $e', tag: 'PassengerLocation');
    }
  }

  Future<void> updatePassengerMarker(
    double lat,
    double lng,
    double bearing, {
    bool force = false,
    double? accuracyMeters,
  }) async {
    if (pointAnnotationManager == null) return;

    final now = DateTime.now();
    if (!force && _lastMarkerAt != null) {
      if (now.difference(_lastMarkerAt!) < _minMarkerInterval) return;
    }
    if (!force && _lastMarkerLat != null && _lastMarkerLng != null) {
      final dLat = (lat - _lastMarkerLat!).abs();
      final dLng = (lng - _lastMarkerLng!).abs();
      if (dLat < _minMoveDeg && dLng < _minMoveDeg) {
        if (accuracyMeters != null && accuracyMeters.isFinite) {
          unawaited(_updateAccuracyCircle(
            lat: lat,
            lng: lng,
            accuracyMeters: accuracyMeters,
          ));
        }
        return;
      }
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
      lastPassengerLat = lat;
      lastPassengerLng = lng;

      if (accuracyMeters != null && accuracyMeters.isFinite) {
        lastPassengerAccuracyMeters = accuracyMeters;
        await _updateAccuracyCircle(
          lat: lat,
          lng: lng,
          accuracyMeters: accuracyMeters,
        );
      }
    } catch (_) {
    } finally {
      _markerBusy = false;
    }
  }

  void _safeSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    MapUtils.showSnackBar(context, message, isError: isError);
  }

  void _announceStage(LocationFixStage stage, geo.Position pos) {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastAnnouncedStage == stage &&
        _lastStageSnackAt != null &&
        now.difference(_lastStageSnackAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastAnnouncedStage = stage;
    _lastStageSnackAt = now;

    final acc = pos.accuracy.isFinite ? pos.accuracy.round() : null;
    final String msg;
    switch (stage) {
      case LocationFixStage.cached:
        msg = acc != null
            ? '📍 موقع تقريبي (آخر معروف · ±$acc م)'
            : '📍 موقع تقريبي من الذاكرة…';
        break;
      case LocationFixStage.quick:
        msg = acc != null
            ? '📡 جارٍ تحسين الدقة… (±$acc م)'
            : '📡 جارٍ تحسين الدقة…';
        break;
      case LocationFixStage.precise:
        msg = acc != null
            ? '✅ دقة محسّنة · ±$acc م'
            : '✅ تم تحسين دقة الموقع';
        break;
    }
    _safeSnack(msg);
  }

  Future<void> goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;

    if (_locateInFlight || isLoadingPassengerLocation) {
      MapUtils.log(
        'تخطي goToMyLocation — طلب موقع جارٍ',
        tag: 'PassengerLocation',
      );
      _fixTracer.mark('blocked_duplicate_tap');
      return;
    }

    _locateInFlight = true;
    _lastAnnouncedStage = null;
    setState(() => isLoadingPassengerLocation = true);
    _fixTracer.start(reason: 'goToMyLocation');
    await _fixTracer.markEnvironment();

    try {
      if (!mounted) {
        _fixTracer.finishFailure('unmounted_before_permission');
        return;
      }

      _fixTracer.mark('permission_begin');
      final hasPermission =
          await LocationPermissionSheet.ensurePermission(context);
      if (!mounted) {
        _fixTracer.finishFailure('unmounted_after_permission');
        return;
      }
      if (!hasPermission) {
        _retryLocateOnResume = false;
        _fixTracer.finishFailure('permission_denied');
        return;
      }
      _fixTracer.mark('permission_ok');

      if (!mounted) {
        _fixTracer.finishFailure('unmounted_before_service');
        return;
      }

      _fixTracer.mark('service_begin');
      final serviceOn =
          await LocationPermissionSheet.ensureLocationService(context);
      if (!mounted) {
        _fixTracer.finishFailure('unmounted_after_service');
        return;
      }
      if (!serviceOn) {
        _retryLocateOnResume = true;
        _fixTracer.finishFailure('location_service_off');
        _safeSnack(
          'فعّل خدمة الموقع ثم ارجع للتطبيق، أو اضغط «موقعي» مجدداً.',
          isError: true,
        );
        return;
      }
      _fixTracer.mark('service_ok');

      _retryLocateOnResume = false;
      _passengerLocationSubscription?.cancel();

      var gotAnyFix = false;

      _fixTracer.mark('progressive_begin');
      final position = await _passengerLocationService.locateProgressive(
        quickTimeout: const Duration(seconds: 2),
        preciseTimeout: const Duration(seconds: 6),
        onProgress: (pos, stage) {
          if (!mounted) return;
          gotAnyFix = true;
          _fixTracer.markStage(stage, pos);
          _announceStage(stage, pos);
          unawaited(
            _applyPosition(pos, moveCamera: true, force: true),
          );
        },
      );

      if (!mounted) {
        _fixTracer.finishFailure('unmounted_after_progressive');
        return;
      }

      if (position == null && !gotAnyFix) {
        _fixTracer.finishFailure('no_fix');
        _safeSnack(
          '❌ تعذر تحديد موقعك حالياً. حاول مرة أخرى.',
          isError: true,
        );
        return;
      }

      if (position != null) {
        await _applyPosition(position, moveCamera: true, force: true);
        if (!mounted) {
          _fixTracer.finishFailure('unmounted_after_apply');
          return;
        }
        final acc = position.accuracy.isFinite
            ? ' (±${position.accuracy.round()} م)'
            : '';
        _safeSnack('📍 تم تحديد موقعك بنجاح$acc');
      }

      if (!mounted) {
        _fixTracer.finishFailure('unmounted_before_stream');
        return;
      }

      isPassengerTrackingActive = true;
      _passengerLocationSubscription = _passengerLocationService
          .getPositionStreamForProfile(LocationTrackingProfile.passengerBrowse)
          .listen((geo.Position pos) {
        if (mounted) {
          unawaited(_applyPosition(pos, moveCamera: false));
        }
      }, onError: (error) {
        MapUtils.log('خطأ في تحديث الموقع: $error', tag: 'PassengerLocation');
        _fixTracer.mark('stream_error', data: {'error': error.toString()});
      });

      _fixTracer.finishSuccess(position);
    } catch (e) {
      _fixTracer.finishFailure('exception', error: e);
      if (mounted) {
        _safeSnack('❌ تعذر تحديد موقعك. حاول مرة أخرى.', isError: true);
      }
      MapUtils.log('خطأ تحديد الموقع: $e', tag: 'PassengerLocation');
    } finally {
      _locateInFlight = false;
      if (mounted) setState(() => isLoadingPassengerLocation = false);
    }
  }

  Future<void> _applyPosition(
    geo.Position position, {
    required bool moveCamera,
    bool force = false,
  }) async {
    lastPassengerLat = position.latitude;
    lastPassengerLng = position.longitude;
    if (position.accuracy.isFinite) {
      lastPassengerAccuracyMeters = position.accuracy;
    }

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
      accuracyMeters:
          position.accuracy.isFinite ? position.accuracy : null,
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
    _fixTracer.markLifecycle(
      AppLifecycleStateLikeX.fromFlutter(state),
    );

    if (state == AppLifecycleState.resumed) {
      if (_locateInFlight || isLoadingPassengerLocation) {
        MapUtils.log(
          'resumed أثناء طلب موقع — بدون إعادة تشغيل',
          tag: 'PassengerLocation',
        );
        _fixTracer.mark('resume_skip_in_flight');
        return;
      }

      if (_retryLocateOnResume && !hasPassengerLocation) {
        _retryLocateOnResume = false;
        _fixTracer.mark('resume_retry_after_settings');
        unawaited(goToMyLocation());
      }
      return;
    }

    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      stopPassengerTracking();
    }
  }

  void disposePassengerLocation() {
    stopPassengerTracking();
    _locateInFlight = false;
    _retryLocateOnResume = false;
    _passengerUserAnnotation = null;
    _accuracyCircle = null;
    _accuracyCircleManager = null;
    lastPassengerAccuracyMeters = null;
  }
}
