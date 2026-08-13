import 'dart:async';
import 'dart:math' as math;

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

  Future<void> showDriverInfoSheet(String driverId) async {
    if (!mounted || _liveTrackingDisposed) return;
    final driver = _driverDataById[driverId];
    if (driver == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => DriverDetailsSheet(driver: driver),
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

class DriverDetailsSheet extends StatelessWidget {
  final LiveDriverLocation driver;

  const DriverDetailsSheet({super.key, required this.driver});

  Color get _accent {
    switch (driver.capacity) {
      case BusCapacity.service:
        return const Color(0xFFF59E0B);
      case BusCapacity.medium:
        return const Color(0xFF3B82F6);
      case BusCapacity.large:
        return const Color(0xFF10B981);
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData get _vehicleIcon {
    switch (driver.capacity) {
      case BusCapacity.service:
        return Icons.airport_shuttle_rounded;
      case BusCapacity.large:
        return Icons.directions_bus_filled_rounded;
      default:
        return Icons.directions_bus_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final isTrip = driver.isTripActive;
    final isOnline = driver.isOnline;
    final statusColor = isTrip
        ? const Color(0xFFDC2626)
        : (isOnline ? const Color(0xFF16A34A) : const Color(0xFF6B7280));
    final statusLabel = isTrip
        ? 'في رحلة نشطة'
        : (isOnline ? 'متصل · متاح' : 'غير متصل');

    final speedKmh = (driver.speed != null &&
            driver.speed!.isFinite &&
            driver.speed! > 0.5)
        ? (driver.speed! * 3.6)
        : null;

    final stale = driver.isStaleWarning;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accent,
                  _accent.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(_vehicleIcon, color: Colors.white, size: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.fullName.isNotEmpty ? driver.fullName : 'سائق',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              driver.vehicleTypeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: stale
                    ? const Color(0xFFFFF7ED)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: stale
                      ? const Color(0xFFFDBA74)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    stale ? Icons.schedule_rounded : Icons.update_rounded,
                    size: 18,
                    color: stale
                        ? const Color(0xFFEA580C)
                        : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stale
                          ? 'آخر تحديث للموقع: ${driver.updatedAgoLabel} — قد يكون الموقع غير دقيق'
                          : 'آخر تحديث للموقع: ${driver.updatedAgoLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stale
                            ? const Color(0xFF9A3412)
                            : const Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.event_seat_rounded,
                        iconColor: _accent,
                        label: 'السعة',
                        value: driver.capacity != null
                            ? '${driver.capacity} راكب'
                            : '—',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.confirmation_number_rounded,
                        iconColor: _accent,
                        label: 'رقم الباص',
                        value: (driver.busNumber != null &&
                                driver.busNumber!.trim().isNotEmpty)
                            ? driver.busNumber!.trim()
                            : '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.route_rounded,
                        iconColor: _accent,
                        label: 'المسار',
                        value: (driver.route != null &&
                                driver.route!.trim().isNotEmpty)
                            ? driver.route!.trim()
                            : '—',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.speed_rounded,
                        iconColor: _accent,
                        label: 'السرعة',
                        value: speedKmh != null
                            ? '${speedKmh.toStringAsFixed(0)} كم/س'
                            : 'متوقف',
                      ),
                    ),
                  ],
                ),
                if (driver.phoneNumber != null &&
                    driver.phoneNumber!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.phone_rounded,
                    iconColor: _accent,
                    label: 'رقم الهاتف',
                    value: driver.phoneNumber!.trim(),
                    fullWidth: true,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: Material(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: const Center(
                    child: Text(
                      'إغلاق',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool fullWidth;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
