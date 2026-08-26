import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

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

  bool isLoadingPassengerLocation = false;
  double currentPassengerBearing = 0.0;
  bool isPassengerTrackingActive = false;

  /// آخر موقع معروف للراكب (لأقرب باص)
  double? lastPassengerLat;
  double? lastPassengerLng;

  DateTime? _lastMarkerAt;
  double? _lastMarkerLat;
  double? _lastMarkerLng;
  bool _markerBusy = false;

  /// يمنع طلب موقع ثانٍ أثناء جريان الأول (single-flight).
  bool _locateInFlight = false;

  /// بعد العودة من إعدادات GPS: إعادة محاولة واحدة بهدوء إن لم نحصل على موقع.
  bool _retryLocateOnResume = false;

  static const Duration _minMarkerInterval = Duration(milliseconds: 220);
  static const double _minMoveDeg = 0.00003;

  LocationService get locationService => _passengerLocationService;

  bool get hasPassengerLocation =>
      lastPassengerLat != null && lastPassengerLng != null;

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
      lastPassengerLat = lat;
      lastPassengerLng = lng;
    } catch (_) {
    } finally {
      _markerBusy = false;
    }
  }

  void _safeSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    MapUtils.showSnackBar(context, message, isError: isError);
  }

  Future<void> goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;

    // single-flight: لا تبدأ طلباً ثانياً أثناء جريان الأول
    if (_locateInFlight || isLoadingPassengerLocation) {
      MapUtils.log(
        'تخطي goToMyLocation — طلب موقع جارٍ',
        tag: 'PassengerLocation',
      );
      return;
    }

    _locateInFlight = true;
    setState(() => isLoadingPassengerLocation = true);

    try {
      // 1) نافذة النظام أولاً (حتى لو GPS مغلق)
      final hasPermission =
          await LocationPermissionSheet.ensurePermission(context);
      if (!mounted) return;
      if (!hasPermission) {
        _retryLocateOnResume = false;
        return;
      }

      // 2) بعد الموافقة: تأكد أن خدمة الموقع مفعّلة
      final serviceOn =
          await LocationPermissionSheet.ensureLocationService(context);
      if (!mounted) return;
      if (!serviceOn) {
        // عند العودة من الإعدادات قد تُفعَّل الخدمة — نعيد المحاولة مرة واحدة
        _retryLocateOnResume = true;
        _safeSnack(
          'فعّل خدمة الموقع ثم ارجع للتطبيق، أو اضغط «موقعي» مجدداً.',
          isError: true,
        );
        return;
      }

      _retryLocateOnResume = false;
      _passengerLocationSubscription?.cancel();

      var gotAnyFix = false;

      final position = await _passengerLocationService.locateProgressive(
        quickTimeout: const Duration(seconds: 2),
        preciseTimeout: const Duration(seconds: 6),
        onProgress: (pos, stage) {
          if (!mounted) return;
          gotAnyFix = true;
          unawaited(_applyPosition(pos, moveCamera: true, force: true));
        },
      );

      if (!mounted) return;

      if (position == null && !gotAnyFix) {
        _safeSnack(
          '❌ تعذر تحديد موقعك حالياً. حاول مرة أخرى.',
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
    if (state == AppLifecycleState.resumed) {
      // لا تعِد تشغيل طلب جارٍ — يمنع التداخل بعد العودة من إعدادات GPS
      if (_locateInFlight || isLoadingPassengerLocation) {
        MapUtils.log(
          'resumed أثناء طلب موقع — بدون إعادة تشغيل',
          tag: 'PassengerLocation',
        );
        return;
      }

      // إعادة محاولة واحدة فقط إن خرج المستخدم لإعدادات الموقع دون نجاح
      if (_retryLocateOnResume && !hasPassengerLocation) {
        _retryLocateOnResume = false;
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
  }
}
