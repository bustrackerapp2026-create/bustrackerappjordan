import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/bus_marker_images.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/live_driver_location.dart';
import '../../../../services/live_tracking_service.dart';

/// يعرض مواقع السائقين المتصلين مباشرة على خريطة الراكب.
/// أيقونة الباص تتغير حسب السعة: سرفيس (5) / متوسط (23) / كبير (50).
mixin PassengerLiveTrackingMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final LiveTrackingService _tracking = LiveTrackingService();
  StreamSubscription<List<LiveDriverLocation>>? _liveDriversSub;

  final Map<String, PointAnnotation> _driverAnnotations = {};
  final Map<String, (double, double)> _lastDrawnPos = {};
  /// آخر سعة رُسمت لكل سائق — لإعادة إنشاء الماركر عند تغيّر نوع الباص
  final Map<String, int?> _lastCapacity = {};

  /// لا يُعاد بناء الخريطة عند تغيّر العدد — فقط اللوحة السفلية
  final ValueNotifier<int> liveDriversCount = ValueNotifier<int>(0);

  String? _routeFilterForTracking;
  bool _updatingMarkers = false;
  List<LiveDriverLocation>? _pendingDrivers;
  Timer? _updateThrottle;

  /// حد أدنى بالمتر تقريباً قبل تحديث موقع الماركر (≈ 12م)
  static const double _minMoveThreshold = 0.00012;

  Future<Uint8List> _markerFor(LiveDriverLocation d) {
    return BusMarkerImages.forCapacity(d.capacity);
  }

  void startLiveDriverTracking({String? routeFilter}) {
    _routeFilterForTracking = routeFilter;
    _liveDriversSub?.cancel();
    _liveDriversSub = _tracking
        .watchOnlineDrivers(routeFilter: routeFilter)
        .listen(_onDriversUpdated, onError: (e) {
      MapUtils.log('خطأ تتبع السائقين: $e', tag: 'LiveTracking');
    });
  }

  void updateLiveTrackingRouteFilter(String? route) {
    if (_routeFilterForTracking == route) return;
    startLiveDriverTracking(routeFilter: route);
  }

  void _onDriversUpdated(List<LiveDriverLocation> drivers) {
    _pendingDrivers = drivers;
    liveDriversCount.value = drivers.length;

    // خنق التحديثات: لا نحدّث الماركرات أكثر من مرة كل 500ms
    if (_updateThrottle?.isActive ?? false) return;
    _updateThrottle = Timer(const Duration(milliseconds: 500), () {
      final pending = _pendingDrivers;
      if (pending != null) {
        unawaited(_applyDriverMarkers(pending));
      }
    });
  }

  Future<void> _applyDriverMarkers(List<LiveDriverLocation> drivers) async {
    if (!mounted || pointAnnotationManager == null) return;
    if (_updatingMarkers) {
      _pendingDrivers = drivers;
      return;
    }
    _updatingMarkers = true;

    try {
      if (!mounted) return;

      final seen = <String>{};
      final toUpdate = <LiveDriverLocation>[];
      final toCreate = <LiveDriverLocation>[];

      for (final d in drivers) {
        seen.add(d.driverId);
        final existing = _driverAnnotations[d.driverId];
        final last = _lastDrawnPos[d.driverId];
        final capacityChanged = _lastCapacity[d.driverId] != d.capacity;

        if (existing != null && capacityChanged) {
          // تغيّر نوع الباص → احذف وأعد الإنشاء بأيقونة جديدة
          try {
            await pointAnnotationManager?.delete(existing);
          } catch (_) {}
          _driverAnnotations.remove(d.driverId);
          _lastDrawnPos.remove(d.driverId);
          _lastCapacity.remove(d.driverId);
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

      // تحديثات متوازية بدفعات صغيرة
      const batch = 4;
      for (var i = 0; i < toUpdate.length; i += batch) {
        if (!mounted) return;
        final slice = toUpdate.skip(i).take(batch);
        await Future.wait(slice.map((d) async {
          final existing = _driverAnnotations[d.driverId];
          if (existing == null) return;
          existing.geometry = Point(
            coordinates: Position(d.longitude, d.latitude),
          );
          if (d.heading != null) existing.iconRotate = d.heading;
          try {
            await pointAnnotationManager?.update(existing);
            _lastDrawnPos[d.driverId] = (d.latitude, d.longitude);
          } catch (_) {}
        }));
      }

      for (final d in toCreate) {
        if (!mounted) return;
        try {
          final image = await _markerFor(d);
          if (!mounted) return;
          final ann = await pointAnnotationManager?.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(d.longitude, d.latitude),
              ),
              image: image,
              iconSize: 0.95,
              iconAnchor: IconAnchor.CENTER,
              iconRotate: d.heading ?? 0,
            ),
          );
          if (ann != null) {
            _driverAnnotations[d.driverId] = ann;
            _lastDrawnPos[d.driverId] = (d.latitude, d.longitude);
            _lastCapacity[d.driverId] = d.capacity;
          }
        } catch (e) {
          MapUtils.log('إنشاء ماركر سائق: $e', tag: 'LiveTracking');
        }
      }

      final toRemove =
          _driverAnnotations.keys.where((id) => !seen.contains(id)).toList();
      for (final id in toRemove) {
        final ann = _driverAnnotations.remove(id);
        _lastDrawnPos.remove(id);
        _lastCapacity.remove(id);
        if (ann != null) {
          try {
            await pointAnnotationManager?.delete(ann);
          } catch (_) {}
        }
      }
    } finally {
      _updatingMarkers = false;
      final pending = _pendingDrivers;
      if (pending != null && pending.length != drivers.length && mounted) {
        _updateThrottle?.cancel();
        _updateThrottle = Timer(const Duration(milliseconds: 250), () {
          unawaited(_applyDriverMarkers(pending));
        });
      }
    }
  }

  void stopLiveDriverTracking() {
    _liveDriversSub?.cancel();
    _liveDriversSub = null;
    _updateThrottle?.cancel();
    _updateThrottle = null;
  }

  Future<void> clearLiveDriverMarkers() async {
    for (final ann in _driverAnnotations.values) {
      try {
        await pointAnnotationManager?.delete(ann);
      } catch (_) {}
    }
    _driverAnnotations.clear();
    _lastDrawnPos.clear();
    _lastCapacity.clear();
    liveDriversCount.value = 0;
  }

  void disposeLiveTracking() {
    stopLiveDriverTracking();
    liveDriversCount.dispose();
    unawaited(clearLiveDriverMarkers());
  }
}
