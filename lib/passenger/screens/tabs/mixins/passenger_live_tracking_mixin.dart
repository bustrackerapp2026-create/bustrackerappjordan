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

  void _safeSetDriversCount(int count) {
    if (_liveTrackingDisposed) return;
    try {
      if (liveDriversCount.value != count) {
        liveDriversCount.value = count;
      }
    } catch (e) {
      debugPrint('liveDriversCount set skipped: $e');
    }
  }

  String? findDriverIdByAnnotation(PointAnnotation annotation) {
    return _annotationToDriverId[annotation.id];
  }

  LiveDriverLocation? getLiveDriverData(String driverId) {
    return _driverDataById[driverId];
  }

  List<LiveDriverLocation> get liveDriversSnapshot =>
      List<LiveDriverLocation>.unmodifiable(_driverDataById.values);

  ({LiveDriverLocation driver, double meters})? findNearestDriver(
    double lat,
    double lng,
  ) {
    LiveDriverLocation? best;
    var bestMeters = double.infinity;

    for (final d in _driverDataById.values) {
      if (!d.hasValidCoords) continue;
      if (!d.isFresh) continue;
      final m = _distanceMeters(lat, lng, d.latitude, d.longitude);
      final score = d.isStaleWarning ? m + 80 : m;
      if (score < bestMeters) {
        bestMeters = score;
        best = d;
      }
    }

    if (best == null) return null;
    final real = _distanceMeters(lat, lng, best.latitude, best.longitude);
    return (driver: best, meters: real);
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
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

  void startLiveDriverTracking({
    String? routeFilter,
    Set<String>? routeNames,
  }) {
    if (_liveTrackingDisposed || !mounted) return;
    _routeFilterForTracking = routeFilter;
    _routeNamesForTracking = routeNames;
    _liveDriversSub?.cancel();
    _liveDriversSub = _tracking
        .watchOnlineDrivers(
          routeFilter: routeFilter,
          routeNames: routeNames,
        )
        .listen(_onDriversUpdated, onError: (e) {
      MapUtils.log('خطأ تتبع السائقين: $e', tag: 'LiveTracking');
    });
  }

  void updateLiveTrackingRouteFilter(String? route) {
    if (_liveTrackingDisposed) return;
    _routeNamesForTracking = null;
    if (_routeFilterForTracking == route && _routeNamesForTracking == null) {
      // قد نكون في وضع متعدد الخطوط — أعد الاشتراك دائماً عند طلب خط واحد
    }
    startLiveDriverTracking(routeFilter: route);
  }

  /// عرض باصات عدة خطوط معاً (وضع «باصات من هنا»).
  void updateLiveTrackingRouteNames(Set<String> routeNames) {
    if (_liveTrackingDisposed) return;
    final cleaned =
        routeNames.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    startLiveDriverTracking(routeNames: cleaned);
  }

  void _onDriversUpdated(List<LiveDriverLocation> drivers) {
    if (_liveTrackingDisposed || !mounted) return;

    for (final d in drivers) {
      _driverDataById[d.driverId] = d;
    }

    _pendingDrivers = drivers;
    _safeSetDriversCount(drivers.length);

    if (_updateThrottle?.isActive ?? false) return;
    _updateThrottle = Timer(const Duration(milliseconds: 500), () {
      if (_liveTrackingDisposed || !mounted) return;
      final pending = _pendingDrivers;
      if (pending != null) {
        unawaited(_applyDriverMarkers(pending));
      }
    });
  }

  Future<void> _applyDriverMarkers(List<LiveDriverLocation> drivers) async {
    if (_liveTrackingDisposed || !mounted || pointAnnotationManager == null) {
      return;
    }
    if (_updatingMarkers) {
      _pendingDrivers = drivers;
      return;
    }
    _updatingMarkers = true;

    try {
      if (_liveTrackingDisposed || !mounted) return;

      final seen = <String>{};
      final toUpdate = <LiveDriverLocation>[];
      final toCreate = <LiveDriverLocation>[];

      for (final d in drivers) {
        seen.add(d.driverId);
        _driverDataById[d.driverId] = d;
        final existing = _driverAnnotations[d.driverId];
        final last = _lastDrawnPos[d.driverId];
        final capacityChanged = _lastCapacity[d.driverId] != d.capacity;
        final staleChanged =
            (_lastStale[d.driverId] ?? false) != d.isStaleWarning;

        if (existing != null && (capacityChanged || staleChanged)) {
          try {
            await pointAnnotationManager?.delete(existing);
          } catch (_) {}
          _annotationToDriverId.remove(existing.id);
          _driverAnnotations.remove(d.driverId);
          _lastDrawnPos.remove(d.driverId);
          _lastCapacity.remove(d.driverId);
          _lastStale.remove(d.driverId);
          toCreate.add(d);
          continue;
        }

        if (existing != null && last != null) {
          final dLat = (d.latitude - last.$1).abs();
          final dLng = (d.longitude - last.$2).abs();
          if (dLat < _minMoveThreshold && dLng < _minMoveThreshold) {
            continue;
          }
          toUpdate.add(d);
        } else if (existing == null) {
          toCreate.add(d);
        } else {
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
          existing.geometry = Point(
            coordinates: Position(d.longitude, d.latitude),
          );
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
              geometry: Point(
                coordinates: Position(d.longitude, d.latitude),
              ),
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
      final pending = _pendingDrivers;
      if (!_liveTrackingDisposed &&
          mounted &&
          pending != null &&
          pending.length != drivers.length) {
        _updateThrottle?.cancel();
        _updateThrottle = Timer(const Duration(milliseconds: 250), () {
          if (_liveTrackingDisposed || !mounted) return;
          unawaited(_applyDriverMarkers(pending));
        });
      }
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
    _lastDrawnPos.clear();
    _lastCapacity.clear();
    _lastStale.clear();

    for (final ann in annotations) {
      try {
        await pointAnnotationManager?.delete(ann);
      } catch (_) {}
    }

    _safeSetDriversCount(0);
  }

  void disposeLiveTracking() {
    if (_liveTrackingDisposed) return;
    _liveTrackingDisposed = true;

    stopLiveDriverTracking();

    final annotations = List<PointAnnotation>.from(_driverAnnotations.values);
    _driverAnnotations.clear();
    _annotationToDriverId.clear();
    _lastDrawnPos.clear();
    _lastCapacity.clear();
    _lastStale.clear();
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
