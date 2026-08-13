import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/trip/eta_utils.dart';
import '../../models/live_driver_location.dart';
import '../../models/trip_model.dart';
import '../../models/trip_status.dart';
import '../../services/live_tracking_service.dart';

/// شريط رحلة الراكب النشطة/قيد الانتظار بأسلوب أوبر.
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

    final statusColor = isPending
        ? const Color(0xFFEA580C)
        : (isActive ? const Color(0xFF16A34A) : Colors.grey);
    final statusText = isPending
        ? 'بانتظار قبول السائق'
        : (isActive ? 'السائق في الطريق إليك' : trip.status.stringValue);

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
    final route = (_driver?.route?.trim().isNotEmpty == true)
        ? _driver!.route!.trim()
        : (trip.route?.trim().isNotEmpty == true ? trip.route!.trim() : null);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_bus_filled_rounded,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (etaLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          etaLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        if (distanceLabel != null)
                          Text(
                            distanceLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (bus != null) _chip(Icons.confirmation_number, 'باص $bus'),
                if (route != null) _chip(Icons.route, route),
                _chip(Icons.place, trip.pickupPoint),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.onFocusDriver != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onFocusDriver,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('تتبع'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (widget.onFocusDriver != null && widget.onCancel != null)
                  const SizedBox(width: 8),
                if (widget.onCancel != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFFB91C1C),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isPending ? 'إلغاء الطلب' : 'إلغاء'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
