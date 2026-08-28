import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/live_driver_location.dart';
import '../../../../passenger/widgets/driver_details_sheet.dart';
import '../../../../services/driver_public_service.dart';

/// تتبع السائقين الأحياء على خريطة الراكب.
mixin PassengerLiveTrackingMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final DriverPublicService _driverPublic = DriverPublicService();

  final Map<String, PointAnnotation> _driverAnnotations = {};
  final Map<String, String> _annotationToDriverId = {};
  final Map<String, LiveDriverLocation> _driverDataById = {};
  final Map<String, (double, double)> _lastDrawnPos = {};
  final Map<String, String?> _lastCapacity = {};
  final Map<String, bool> _lastStale = {};

  StreamSubscription<List<LiveDriverLocation>>? _liveDriversSub;
  Timer? _updateThrottle;
  List<LiveDriverLocation>? _pendingDrivers;
  bool _updatingMarkers = false;
  bool _liveTrackingDisposed = false;

  final ValueNotifier<int> liveDriversCount = ValueNotifier<int>(0);
  String? _routeFilter;

  LiveDriverLocation? getLiveDriverData(String driverId) =>
      _driverDataById[driverId];

  String? findDriverIdByAnnotation(PointAnnotation annotation) {
    return _annotationToDriverId[annotation.id];
  }

  void startLiveDriverTracking({String? routeFilter}) {
    _routeFilter = routeFilter;
    _liveDriversSub?.cancel();
    _liveDriversSub = _driverPublic.watchOnlineDrivers().listen(
      (drivers) {
        if (_liveTrackingDisposed || !mounted) return;
        _pendingDrivers = drivers;
        _scheduleApply();
      },
      onError: (e) => debugPrint('live drivers watch: $e'),
    );
  }

  void updateLiveTrackingRouteFilter(String? route) {
    _routeFilter = route;
    final pending = _pendingDrivers;
    if (pending != null) unawaited(_applyDriverMarkers(pending));
  }

  void updateLiveTrackingRouteNames(Set<String> names) {}

  void _scheduleApply() {
    _updateThrottle?.cancel();
    _updateThrottle = Timer(const Duration(milliseconds: 280), () {
      if (_liveTrackingDisposed || !mounted) return;
      final pending = _pendingDrivers;
      if (pending != null) unawaited(_applyDriverMarkers(pending));
    });
  }

  Future<Uint8List> _markerFor(LiveDriverLocation d) async {
    // تفويض لـ MapUtils إن وُجدت صورة مخصصة؛ وإلا نقطة بسيطة عبر نص
    return Uint8List(0);
  }

  Future<void> _applyDriverMarkers(List<LiveDriverLocation> drivers) async {
    if (_updatingMarkers || _liveTrackingDisposed || !mounted) return;
    _updatingMarkers = true;
    try {
      var list = drivers;
      final filter = _routeFilter?.trim();
      if (filter != null && filter.isNotEmpty) {
        list = drivers
            .where((d) {
              final r = d.route?.trim() ?? '';
              return r.isEmpty || r == filter;
            })
            .toList();
      }
      liveDriversCount.value = list.length;
      final seen = <String>{};

      for (final d in list) {
        if (_liveTrackingDisposed) return;
        if (!d.hasValidCoords) continue;
        seen.add(d.driverId);
        _driverDataById[d.driverId] = d;

        final existing = _driverAnnotations[d.driverId];
        if (existing != null) {
          try {
            existing.geometry =
                Point(coordinates: Position(d.longitude, d.latitude));
            if (d.heading != null) existing.iconRotate = d.heading;
            existing.iconSize = d.isStaleWarning ? 0.78 : 0.95;
            await pointAnnotationManager?.update(existing);
            _lastDrawnPos[d.driverId] = (d.latitude, d.longitude);
            _lastCapacity[d.driverId] = d.capacity;
            _lastStale[d.driverId] = d.isStaleWarning;
          } catch (_) {}
          continue;
        }

        try {
          final ann = await pointAnnotationManager?.create(
            PointAnnotationOptions(
              geometry:
                  Point(coordinates: Position(d.longitude, d.latitude)),
              iconSize: d.isStaleWarning ? 0.78 : 0.95,
              iconAnchor: IconAnchor.CENTER,
              iconRotate: d.heading ?? 0,
              textField: d.busNumber ?? '',
              textSize: 11.0,
              textOffset: [0.0, 1.4],
            ),
          );
          if (ann != null) {
            _driverAnnotations[d.driverId] = ann;
            _annotationToDriverId[ann.id] = d.driverId;
            _lastDrawnPos[d.driverId] = (d.latitude, d.longitude);
            _lastCapacity[d.driverId] = d.capacity;
            _lastStale[d.driverId] = d.isStaleWarning;
          }
        } catch (e) {
          MapUtils.log('إنشاء ماركر سائق: $e', tag: 'LiveTracking');
        }
      }

      final toRemove =
          _driverAnnotations.keys.where((id) => !seen.contains(id)).toList();
      for (final id toRemove) {
        final ann = _driverAnnotations.remove(id);
        _lastDrawnPos.remove(id);
        _lastCapacity.remove(id);
        _lastStale.remove(id);
        _driverDataById.remove(id);
        if (ann != null) {
          _annotationToDriverId.remove(ann.id);
          try {
            await pointAnnotationManager?.delete(ann);
          } catch (_) {}
        }
      }
    } finally {
      _updatingMarkers = false;
    }
  }

  Future<void> showDriverInfoSheet(
    String driverId, {
    double? passengerLat,
    double? passengerLng,
    Future<void> Function(LiveDriverLocation driver)? onRequestBoard,
    void Function(LiveDriverLocation driver)? onFollowBus,
  }) async {
    if (!mounted || _liveTrackingDisposed) return;
    final driver = _driverDataById[driverId];
    if (driver == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (ctx) => DriverDetailsSheet(
        driver: driver,
        passengerLat: passengerLat,
        passengerLng: passengerLng,
        onRequestBoard: onRequestBoard,
        onFollowBus: onFollowBus,
      ),
    );
  }

  void stopLiveDriverTracking() {
    _liveDriversSub?.cancel();
    _liveDriversSub = null;
    _updateThrottle?.cancel();
    _updateThrottle = null;
    _pendingDrivers = null;
  }

  Future<void> clearLiveDriverMarkers() async {
    final annotations = List<PointAnnotation>.from(_driverAnnotations.values);
    _driverAnnotations.clear();
    _annotationToDriverId.clear();
    for (final ann in annotations) {
      try {
        await pointAnnotationManager?.delete(ann);
      } catch (_) {}
    }
  }

  void disposeLiveTracking() {
    _liveTrackingDisposed = true;
    stopLiveDriverTracking();
    final annotations = List<PointAnnotation>.from(_driverAnnotations.values);
    _driverAnnotations.clear();
    _annotationToDriverId.clear();
    _driverDataById.clear();
    for (final ann in annotations) {
      unawaited(() async {
        try {
          await pointAnnotationManager?.delete(ann);
        } catch (_) {}
      }());
    }
    try {
      liveDriversCount.dispose();
    } catch (_) {}
  }
}
