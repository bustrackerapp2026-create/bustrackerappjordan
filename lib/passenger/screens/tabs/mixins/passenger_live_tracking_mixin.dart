import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/live_driver_location.dart';
import '../../../../services/driver_public_service.dart';
import '../../../../passenger/widgets/driver_details_sheet.dart';

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
      onError: (e) {
        debugPrint('live drivers watch: $e');
      },
    );
  }

  void updateLiveTrackingRouteFilter(String? route) {
    _routeFilter = route;
    final pending = _pendingDrivers;
    if (pending != null) {
      unawaited(_applyDriverMarkers(pending));
    }
  }

  void updateLiveTrackingRouteNames(Set<String> names) {
    // reserved for multi-route filter
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
        final stale = d.isStaleWarning;
        final pos = (d.latitude, d.longitude);

        if (existing != null) {
          final last = _lastDrawnPos[d.driverId];
          final moved = last == null ||
              (last.$1 - d.latitude).abs() > 0.00001 ||
              (last.$2 - d.longitude).abs() > 0.00001;
          final capacityChanged = _lastCapacity[d.driverId] != d.capacity;
          final staleChanged = _lastStale[d.driverId] != stale;
          if (!moved && !capacityChanged && !staleChanged) continue;

          try {
            await pointAnnotationManager?.update(
              existing,
              PointAnnotationOptions(
                geometry: Point(
                  coordinates: Position(d.longitude, d.latitude),
                ),
              ),
            );
            _lastDrawnPos[d.driverId] = pos;
            _lastCapacity[d.driverId] = d.capacity;
            _lastStale[d.driverId] = stale;
          } catch (e) {
            MapUtils.log('تحديث ماركر سائق: $e', tag: 'LiveTracking');
          }
          continue;
        }

        try {
          final ann = await pointAnnotationManager?.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(d.longitude, d.latitude),
              ),
              iconSize: 1.0,
              textField: d.busNumber ?? '',
              textSize: 11.0,
              textOffset: [0.0, 1.2],
            ),
          );
          if (ann != null) {
            _driverAnnotations[d.driverId] = ann;
            _annotationToDriverId[ann.id] = d.driverId;
            _lastDrawnPos[d.driverId] = pos;
            _lastCapacity[d.driverId] = d.capacity;
            _lastStale[d.driverId] = stale;
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
    _lastDrawnPos.clear();
    _lastCapacity.clear();
    _lastStale.clear();
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
