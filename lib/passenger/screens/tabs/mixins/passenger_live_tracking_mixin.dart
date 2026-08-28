import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/bus_marker_images.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/live_driver_location.dart';
import '../../../../services/live_tracking_service.dart';
import '../../../widgets/driver_details_sheet.dart';

mixin PassengerLiveTrackingMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final LiveTrackingService _tracking = LiveTrackingService();
  StreamSubscription<List<LiveDriverLocation>>? _liveDriversSub;

  final Map<String, PointAnnotation> _driverAnnotations = {};
  final Map<String, String> _annotationToDriverId = {};
  final Map<String, LiveDriverLocation> _driverDataById = {};
  final Map<String, (double, double)> _lastDrawnPos = {};
  final Map<String, int?> _lastCapacity = {};
  final Map<String, bool> _lastStale = {};

  final ValueNotifier<int> liveDriversCount = ValueNotifier<int>(0);

  String? _routeFilterForTracking;
  Set<String>? _routeNamesForTracking;
  bool _updatingMarkers = false;
  bool _liveTrackingDisposed = false;
  List<LiveDriverLocation>? _pendingDrivers;
  Timer? _updateThrottle;

  static const double _minMoveThreshold = 0.00012;

  Future<Uint8List> _markerFor(LiveDriverLocation d) {
    return BusMarkerImages.forCapacity(d.capacity, stale: d.isStaleWarning);
  }

  LiveDriverLocation? getLiveDriverData(String driverId) =>
      _driverDataById[driverId];

  String? findDriverIdByAnnotation(PointAnnotation annotation) {
    return _annotationToDriverId[annotation.id];
  }

  ({LiveDriverLocation driver, double meters})? findNearestDriver(
    double lat,
    double lng, {
    double maxMeters = 2500,
  }) {
    ({LiveDriverLocation driver, double meters})? best;
    for (final d in _driverDataById.values) {
      if (!d.hasValidCoords) continue;
      final m = _haversine(lat, lng, d.latitude, d.longitude);
      if (m > maxMeters) continue;
      if (best == null || m < best.meters) {
        best = (driver: d, meters: m);
      }
    }
    return best;
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void startLiveDriverTracking({String? routeFilter}) {
    _routeFilterForTracking = routeFilter;
    _liveDriversSub?.cancel();
    _liveDriversSub = _tracking.watchOnlineDrivers().listen(
      (drivers) {
        if (_liveTrackingDisposed || !mounted) return;
        _pendingDrivers = drivers;
        _scheduleApply();
      },
      onError: (e) => debugPrint('live drivers watch: $e'),
    );
  }

  void updateLiveTrackingRouteFilter(String? route) {
    _routeFilterForTracking = route;
    final pending = _pendingDrivers;
    if (pending != null) unawaited(_applyDriverMarkers(pending));
  }

  void updateLiveTrackingRouteNames(Set<String> names) {
    _routeNamesForTracking = names;
  }

  void _scheduleApply() {
    _updateThrottle?.cancel();
    _updateThrottle = Timer(const Duration(milliseconds: 280), () {
      if (_liveTrackingDisposed || !mounted) return;
      final pending = _pendingDrivers;
      if (pending != null) unawaited(_applyDriverMarkers(pending));
    });
  }

  Future<void> _applyDriverMarkers(List<LiveDriverLocation> drivers) async {
    if (_updatingMarkers || _liveTrackingDisposed || !mounted) return;
    _updatingMarkers = true;
    try {
      var list = drivers;
      final filter = _routeFilterForTracking?.trim();
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
      final toCreate = <LiveDriverLocation>[];
      final toUpdate = <LiveDriverLocation>[];

      for (final d in list) {
        if (_liveTrackingDisposed) return;
        if (!d.hasValidCoords) continue;
        seen.add(d.driverId);
        _driverDataById[d.driverId] = d;

        final existing = _driverAnnotations[d.driverId];
        final last = _lastDrawnPos[d.driverId];
        final moved = last == null ||
            (last.$1 - d.latitude).abs() > _minMoveThreshold ||
            (last.$2 - d.longitude).abs() > _minMoveThreshold;
        final capacityChanged = _lastCapacity[d.driverId] != d.capacity;
        final staleChanged = _lastStale[d.driverId] != d.isStaleWarning;

        if (existing != null && (capacityChanged || staleChanged)) {
          try {
            await pointAnnotationManager?.delete(existing);
          } catch (_) {}
          _driverAnnotations.remove(d.driverId);
          _annotationToDriverId.remove(existing.id);
          toCreate.add(d);
        } else if (existing == null) {
          toCreate.add(d);
        } else if (moved) {
          toUpdate.add(d);
        }
      }

      const batch = 4;
      for (var i = 0; i < toUpdate.length; i += batch) {
        if (_liveTrackingDisposed || !mounted) return;
        final slice = toUpdate.skip(i).take(batch);
        await Future.wait(slice.map((d) async {
          final existing = _driverAnnotations[d.driverId];
          if (existing == null) return;
          existing.geometry =
              Point(coordinates: Position(d.longitude, d.latitude));
          if (d.heading != null) existing.iconRotate = d.heading;
          existing.iconSize = d.isStaleWarning ? 0.78 : 0.95;
          try {
            await pointAnnotationManager?.update(existing);
            _lastDrawnPos[d.driverId] = (d.latitude, d.longitude);
          } catch (_) {}
        }));
      }

      for (final d in toCreate) {
        if (_liveTrackingDisposed || !mounted) return;
        try {
          final image = await _markerFor(d);
          if (_liveTrackingDisposed || !mounted) return;
          final ann = await pointAnnotationManager?.create(
            PointAnnotationOptions(
              geometry:
                  Point(coordinates: Position(d.longitude, d.latitude)),
              image: image,
              iconSize: d.isStaleWarning ? 0.78 : 0.95,
              iconAnchor: IconAnchor.CENTER,
              iconRotate: d.heading ?? 0,
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
      for (final id in toRemove) {
        if (_liveTrackingDisposed) return;
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
  }) async {
    if (!mounted || _liveTrackingDisposed) return;
    final driver = _driverDataById[driverId];
    if (driver == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => DriverDetailsSheet(
        driver: driver,
        passengerLat: passengerLat,
        passengerLng: passengerLng,
        onRequestBoard: onRequestBoard,
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
