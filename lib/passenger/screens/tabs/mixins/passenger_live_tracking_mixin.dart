import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
  final Map<String, int?> _lastCapacity = {};

  /// عدد السائقين المتصلين للوحة السفلية فقط
  final ValueNotifier<int> liveDriversCount = ValueNotifier<int>(0);

  String? _routeFilterForTracking;
  bool _updatingMarkers = false;
  bool _liveTrackingDisposed = false;
  List<LiveDriverLocation>? _pendingDrivers;
  Timer? _updateThrottle;

  static const double _minMoveThreshold = 0.00012;

  Future<Uint8List> _markerFor(LiveDriverLocation d) {
    return BusMarkerImages.forCapacity(d.capacity);
  }

  void _safeSetDriversCount(int count) {
    if (_liveTrackingDisposed) return;
    try {
      if (liveDriversCount.value != count) {
        liveDriversCount.value = count;
      }
    } catch (e) {
      // ValueNotifier قد يكون disposed أثناء إغلاق الشاشة
      debugPrint('liveDriversCount set skipped: $e');
    }
  }

  void startLiveDriverTracking({String? routeFilter}) {
    if (_liveTrackingDisposed || !mounted) return;
    _routeFilterForTracking = routeFilter;
    _liveDriversSub?.cancel();
    _liveDriversSub = _tracking
        .watchOnlineDrivers(routeFilter: routeFilter)
        .listen(_onDriversUpdated, onError: (e) {
      MapUtils.log('خطأ تتبع السائقين: $e', tag: 'LiveTracking');
    });
  }

  void updateLiveTrackingRouteFilter(String? route) {
    if (_liveTrackingDisposed) return;
    if (_routeFilterForTracking == route) return;
    startLiveDriverTracking(routeFilter: route);
  }

  void _onDriversUpdated(List<LiveDriverLocation> drivers) {
    if (_liveTrackingDisposed || !mounted) return;

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
        final existing = _driverAnnotations[d.driverId];
        final last = _lastDrawnPos[d.driverId];
        final capacityChanged = _lastCapacity[d.driverId] != d.capacity;

        if (existing != null && capacityChanged) {
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
        if (_liveTrackingDisposed) return;
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
    _lastDrawnPos.clear();
    _lastCapacity.clear();

    for (final ann in annotations) {
      try {
        await pointAnnotationManager?.delete(ann);
      } catch (_) {}
    }

    // لا تلمس ValueNotifier إذا تم dispose
    _safeSetDriversCount(0);
  }

  /// ترتيب آمن: إيقاف البث → مسح الماركرات → ثم dispose للـ notifier
  void disposeLiveTracking() {
    if (_liveTrackingDisposed) return;
    _liveTrackingDisposed = true;

    stopLiveDriverTracking();

    // مسح الماركرات بدون انتظار (لا يكتب على notifier بعد العلم بالـ dispose)
    final annotations = List<PointAnnotation>.from(_driverAnnotations.values);
    _driverAnnotations.clear();
    _lastDrawnPos.clear();
    _lastCapacity.clear();
    for (final ann in annotations) {
      unawaited(() async {
        try {
          await pointAnnotationManager?.delete(ann);
        } catch (_) {}
      }());
    }

    // أخيراً: dispose بعد إيقاف كل المصادر التي قد تكتب عليه
    try {
      liveDriversCount.dispose();
    } catch (_) {}
  }
}
