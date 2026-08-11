import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/live_driver_location.dart';
import '../../../../services/live_tracking_service.dart';

/// يعرض مواقع السائقين المتصلين مباشرة على خريطة الراكب.
mixin PassengerLiveTrackingMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final LiveTrackingService _tracking = LiveTrackingService();
  StreamSubscription<List<LiveDriverLocation>>? _liveDriversSub;

  final Map<String, PointAnnotation> _driverAnnotations = {};
  final Map<String, (double, double)> _lastDrawnPos = {};
  Uint8List? _busMarkerBytes;

  /// لا يُعاد بناء الخريطة عند تغيّر العدد — فقط اللوحة السفلية
  final ValueNotifier<int> liveDriversCount = ValueNotifier<int>(0);

  String? _routeFilterForTracking;
  bool _updatingMarkers = false;
  List<LiveDriverLocation>? _pendingDrivers;
  Timer? _updateThrottle;

  /// حد أدنى بالمتر تقريباً قبل تحديث موقع الماركر (≈ 8م)
  static const double _minMoveThreshold = 0.00008;

  Future<Uint8List> _createBusMarkerBytes() async {
    if (_busMarkerBytes != null) return _busMarkerBytes!;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 88.0;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 2), 18, shadow);

    final body = Paint()..color = const Color(0xFF1565C0);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(size / 2, size / 2),
        width: 34,
        height: 42,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, body);

    final window = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(size / 2, size / 2 - 6),
          width: 22,
          height: 12,
        ),
        const Radius.circular(3),
      ),
      window,
    );

    final wheel = Paint()..color = Colors.black87;
    canvas.drawCircle(const Offset(size / 2 - 9, size / 2 + 16), 4, wheel);
    canvas.drawCircle(const Offset(size / 2 + 9, size / 2 + 16), 4, wheel);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    _busMarkerBytes = bytes!.buffer.asUint8List();
    return _busMarkerBytes!;
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

    // خنق التحديثات: لا نحدّث الماركرات أكثر من مرة كل 400ms
    if (_updateThrottle?.isActive ?? false) return;
    _updateThrottle = Timer(const Duration(milliseconds: 400), () {
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
      final image = await _createBusMarkerBytes();
      if (!mounted) return;

      final seen = <String>{};

      for (final d in drivers) {
        if (!mounted) return;
        seen.add(d.driverId);
        final existing = _driverAnnotations[d.driverId];
        final last = _lastDrawnPos[d.driverId];

        // تخطي التحديث إن الحركة طفيفة جداً
        if (existing != null && last != null) {
          final dLat = (d.latitude - last.$1).abs();
          final dLng = (d.longitude - last.$2).abs();
          if (dLat < _minMoveThreshold && dLng < _minMoveThreshold) {
            continue;
          }
        }

        final point = Point(
          coordinates: Position(d.longitude, d.latitude),
        );

        if (existing != null) {
          existing.geometry = point;
          if (d.heading != null) {
            existing.iconRotate = d.heading;
          }
          try {
            await pointAnnotationManager?.update(existing);
            _lastDrawnPos[d.driverId] = (d.latitude, d.longitude);
          } catch (_) {}
        } else {
          try {
            final ann = await pointAnnotationManager?.create(
              PointAnnotationOptions(
                geometry: point,
                image: image,
                iconSize: 1.0,
                iconAnchor: IconAnchor.CENTER,
                iconRotate: d.heading ?? 0,
                textField: d.displayLabel,
                textSize: 11.0,
                textOffset: [0.0, 1.8],
                textColor: const Color(0xFF0D47A1).toARGB32(),
                textHaloColor: const Color(0xFFFFFFFF).toARGB32(),
                textHaloWidth: 1.2,
              ),
            );
            if (ann != null) {
              _driverAnnotations[d.driverId] = ann;
              _lastDrawnPos[d.driverId] = (d.latitude, d.longitude);
            }
          } catch (e) {
            MapUtils.log('إنشاء ماركر سائق: $e', tag: 'LiveTracking');
          }
        }
      }

      final toRemove =
          _driverAnnotations.keys.where((id) => !seen.contains(id)).toList();
      for (final id in toRemove) {
        final ann = _driverAnnotations.remove(id);
        _lastDrawnPos.remove(id);
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
        _updateThrottle = Timer(const Duration(milliseconds: 200), () {
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
    liveDriversCount.value = 0;
  }

  void disposeLiveTracking() {
    stopLiveDriverTracking();
    liveDriversCount.dispose();
    unawaited(clearLiveDriverMarkers());
  }
}
