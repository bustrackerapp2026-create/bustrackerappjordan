import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/constants/bus_capacity.dart';
import '../../../../core/map/bus_marker_images.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/live_driver_location.dart';
import '../../../../services/live_tracking_service.dart';

/// يعرض مواقع السائقين المتصلين مباشرة على خريطة الراكب.
/// الضغط على أيقونة الباص/السرفيس يعرض معلومات السائق.
mixin PassengerLiveTrackingMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final LiveTrackingService _tracking = LiveTrackingService();
  StreamSubscription<List<LiveDriverLocation>>? _liveDriversSub;

  final Map<String, PointAnnotation> _driverAnnotations = {};
  /// annotation.id → driverId
  final Map<String, String> _annotationToDriverId = {};
  /// آخر بيانات معروفة لكل سائق (لعرض التفاصيل عند الضغط)
  final Map<String, LiveDriverLocation> _driverDataById = {};
  final Map<String, (double, double)> _lastDrawnPos = {};
  final Map<String, int?> _lastCapacity = {};

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
      debugPrint('liveDriversCount set skipped: $e');
    }
  }

  /// هل هذه العلامة لسائق حي؟
  String? findDriverIdByAnnotation(PointAnnotation annotation) {
    return _annotationToDriverId[annotation.id];
  }

  LiveDriverLocation? getLiveDriverData(String driverId) {
    return _driverDataById[driverId];
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

        if (existing != null && capacityChanged) {
          try {
            await pointAnnotationManager?.delete(existing);
          } catch (_) {}
          _annotationToDriverId.remove(existing.id);
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
            _annotationToDriverId[ann.id] = d.driverId;
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

  /// عرض ورقة معلومات السائق عند الضغط على أيقونة الباص/السرفيس.
  Future<void> showDriverInfoSheet(String driverId) async {
    if (!mounted || _liveTrackingDisposed) return;
    final driver = _driverDataById[driverId];
    if (driver == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DriverInfoSheet(driver: driver);
      },
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
    // نُبقي _driverDataById حتى لا تفقد الورقة بياناتها أثناء الإغلاق

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

/// ورقة منبثقة بمعلومات السائق عند الضغط على الماركر.
class _DriverInfoSheet extends StatelessWidget {
  final LiveDriverLocation driver;

  const _DriverInfoSheet({required this.driver});

  @override
  Widget build(BuildContext context) {
    final isService = driver.capacity == BusCapacity.service;
    final vehicleIcon =
        isService ? Icons.airport_shuttle_rounded : Icons.directions_bus_filled;
    final statusColor =
        driver.isTripActive ? Colors.red.shade700 : Colors.green.shade700;
    final statusText = driver.isTripActive
        ? 'في رحلة نشطة'
        : (driver.isOnline ? 'متصل · متاح' : 'غير متصل');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Icon(
                  vehicleIcon,
                  color: AppTheme.primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.fullName.isNotEmpty ? driver.fullName : 'سائق',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _infoRow(
            Icons.directions_bus_outlined,
            'نوع المركبة',
            driver.vehicleTypeLabel,
          ),
          _infoRow(
            Icons.event_seat_outlined,
            'السعة',
            driver.capacityLabel,
          ),
          if (driver.busNumber != null &&
              driver.busNumber!.trim().isNotEmpty)
            _infoRow(
              Icons.confirmation_number_outlined,
              'رقم الباص',
              driver.busNumber!.trim(),
            ),
          if (driver.route != null && driver.route!.trim().isNotEmpty)
            _infoRow(
              Icons.route_outlined,
              'المسار / الخط',
              driver.route!.trim(),
            ),
          if (driver.phoneNumber != null &&
              driver.phoneNumber!.trim().isNotEmpty)
            _infoRow(
              Icons.phone_outlined,
              'الهاتف',
              driver.phoneNumber!.trim(),
            ),
          if (driver.speed != null &&
              driver.speed!.isFinite &&
              driver.speed! > 0)
            _infoRow(
              Icons.speed,
              'السرعة',
              '${(driver.speed! * 3.6).toStringAsFixed(0)} كم/س',
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'إغلاق',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
