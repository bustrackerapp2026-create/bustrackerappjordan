import 'package:flutter/material.dart';

import '../../core/constants/bus_capacity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/trip/eta_utils.dart';
import '../../models/live_driver_location.dart';

/// ورقة تفاصيل السائق على خريطة الراكب.
class DriverDetailsSheet extends StatefulWidget {
  final LiveDriverLocation driver;
  final double? passengerLat;
  final double? passengerLng;
  final Future<void> Function(LiveDriverLocation driver)? onRequestBoard;

  const DriverDetailsSheet({
    super.key,
    required this.driver,
    this.passengerLat,
    this.passengerLng,
    this.onRequestBoard,
  });

  @override
  State<DriverDetailsSheet> createState() => _DriverDetailsSheetState();
}

class _DriverDetailsSheetState extends State<DriverDetailsSheet> {
  bool _requesting = false;

  LiveDriverLocation get driver => widget.driver;

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

    String? etaText;
    String? distanceText;
    if (widget.passengerLat != null &&
        widget.passengerLng != null &&
        driver.hasValidCoords) {
      final meters = EtaUtils.distanceMeters(
        widget.passengerLat!,
        widget.passengerLng!,
        driver.latitude,
        driver.longitude,
      );
      final mins = EtaUtils.estimateMinutes(
        distanceMeters: meters,
        speedMps: driver.speed,
      );
      etaText = EtaUtils.formatEta(mins);
      distanceText = EtaUtils.formatDistance(meters);
    }

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
          if (etaText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: Color(0xFF059669)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الوصول التقريبي: $etaText · المسافة $distanceText',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
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
                      child: _DriverInfoCard(
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
                      child: _DriverInfoCard(
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
                      child: _DriverInfoCard(
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
                      child: _DriverInfoCard(
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
                  _DriverInfoCard(
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
            child: Column(
              children: [
                if (widget.onRequestBoard != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _requesting
                          ? null
                          : () async {
                              setState(() => _requesting = true);
                              try {
                                await widget.onRequestBoard!(driver);
                                if (context.mounted) Navigator.pop(context);
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _requesting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _requesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.hail_rounded),
                      label: Text(
                        _requesting
                            ? 'جاري إرسال الطلب...'
                            : 'طلب صعود من موقعي',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool fullWidth;

  const _DriverInfoCard({
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
