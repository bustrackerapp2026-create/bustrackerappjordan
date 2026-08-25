import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/trip/eta_utils.dart';
import '../../models/live_driver_location.dart';
import '../../models/trip_model.dart';
import '../../models/trip_status.dart';
import '../../services/live_tracking_service.dart';

/// بطاقة رحلة الراكب النشطة — تصميم فاخر بشريط بنفسجي جانبي.
class ActiveTripBanner extends StatefulWidget {
  final TripModel trip;
  final VoidCallback? onCancel;
  final VoidCallback? onFocusDriver;

  const ActiveTripBanner({
    super.key,
    required this.trip,
    this.onCancel,
    this.onFocusDriver,
  });

  @override
  State<ActiveTripBanner> createState() => _ActiveTripBannerState();
}

class _ActiveTripBannerState extends State<ActiveTripBanner> {
  StreamSubscription<LiveDriverLocation?>? _sub;
  LiveDriverLocation? _driver;
  bool _notifiedApproach = false;

  @override
  void initState() {
    super.initState();
    _listenDriver();
  }

  @override
  void didUpdateWidget(covariant ActiveTripBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.driverId != widget.trip.driverId) {
      _notifiedApproach = false;
      _listenDriver();
    }
  }

  void _listenDriver() {
    _sub?.cancel();
    final id = widget.trip.driverId;
    if (id.isEmpty) return;
    _sub = LiveTrackingService().watchDriver(id).listen((d) {
      if (!mounted) return;
      setState(() => _driver = d);
      _maybeNotifyApproach(d);
    });
  }

  void _maybeNotifyApproach(LiveDriverLocation? d) {
    if (_notifiedApproach || d == null || !d.hasValidCoords) return;
    final lat = widget.trip.pickupLat;
    final lng = widget.trip.pickupLng;
    if (lat == null || lng == null) return;

    final meters =
        EtaUtils.distanceMeters(lat, lng, d.latitude, d.longitude);
    final mins = EtaUtils.estimateMinutes(
      distanceMeters: meters,
      speedMps: d.speed,
    );
    if (mins <= 3) {
      _notifiedApproach = true;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text('🚌 ${EtaUtils.approachingMessage(mins)}'),
          backgroundColor: const Color(0xFF0F766E),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isPending = trip.status == TripStatus.pending;
    final isActive = trip.status == TripStatus.active;

    String? etaLabel;
    String? distanceLabel;
    if (_driver != null &&
        _driver!.hasValidCoords &&
        trip.pickupLat != null &&
        trip.pickupLng != null) {
      final meters = EtaUtils.distanceMeters(
        trip.pickupLat!,
        trip.pickupLng!,
        _driver!.latitude,
        _driver!.longitude,
      );
      final mins = EtaUtils.estimateMinutes(
        distanceMeters: meters,
        speedMps: _driver!.speed,
      );
      etaLabel = EtaUtils.formatEta(mins);
      distanceLabel = EtaUtils.formatDistance(meters);
    }

    final accent = isPending
        ? const Color(0xFF7C3AED)
        : (isActive ? const Color(0xFF0F766E) : const Color(0xFF64748B));
    final statusText = isPending
        ? 'بانتظار السائق'
        : (isActive ? 'السائق في الطريق' : trip.status.stringValue);

    final driverTitle = (_driver?.fullName.isNotEmpty == true)
        ? _driver!.fullName
        : (trip.driverName?.isNotEmpty == true
            ? trip.driverName!
            : 'سائق');
    final bus = (_driver?.busNumber?.trim().isNotEmpty == true)
        ? _driver!.busNumber!.trim()
        : (trip.busNumber?.trim().isNotEmpty == true
            ? trip.busNumber!.trim()
            : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent,
                    accent.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_bus_rounded,
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (etaLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 14, color: accent),
                                const SizedBox(width: 4),
                                Text(
                                  etaLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                                if (distanceLabel != null) ...[
                                  Text(
                                    ' · $distanceLabel',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: accent.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      driverTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bus != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'كوستر $bus',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.place_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.pickupPoint,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'نقطة الاستلام',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (widget.onCancel != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(
                                  color: Color(0xFFFECACA),
                                  width: 1.4,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                isPending ? 'إلغاء الطلب' : 'إلغاء',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        if (widget.onCancel != null &&
                            widget.onFocusDriver != null)
                          const SizedBox(width: 10),
                        if (widget.onFocusDriver != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.onFocusDriver,
                              icon: const Icon(Icons.near_me_rounded, size: 18),
                              label: const Text(
                                'تتبع السائق',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
