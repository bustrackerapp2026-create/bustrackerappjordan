import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/bus_capacity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/trip/eta_utils.dart';
import '../../models/live_driver_location.dart';

/// بطاقة تفاصيل السائق على خريطة الراكب.
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

    final bus = driver.busNumber?.trim();
    final routeTitle = driver.route?.trim();
    final routeDetail = driver.routeDetail?.trim();
    final phone = driver.phoneNumber?.trim();

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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
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
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          _accent,
                          _accent.withValues(alpha: 0.78),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.directions_bus_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.fullName.isNotEmpty
                                        ? driver.fullName
                                        : 'سائق',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
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
                                        const SizedBox(width: 6),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (bus != null && bus.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.confirmation_number_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'رقم المركبة: $bus',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (etaText != null) ...[
                    const SizedBox(height: 12),
                    _infoBanner(
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFF059669),
                      bg: const Color(0xFFECFDF5),
                      border: const Color(0xFFA7F3D0),
                      text: 'الوصول التقريبي: $etaText · المسافة $distanceText',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _sectionCard(
                    title: 'اتجاه الخط',
                    icon: Icons.route_rounded,
                    child: Text(
                      (routeTitle != null && routeTitle.isNotEmpty)
                          ? routeTitle
                          : 'لم يُحدَّد اتجاه الخط بعد',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: (routeTitle != null && routeTitle.isNotEmpty)
                            ? AppTheme.textColor
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionCard(
                    title: 'مسير الخط (المناطق بالترتيب)',
                    icon: Icons.alt_route_rounded,
                    child: Text(
                      (routeDetail != null && routeDetail.isNotEmpty)
                          ? routeDetail
                          : 'أضف السائق تفاصيل المناطق التي يمر بها الخط من ملفه الشخصي.',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                        color: (routeDetail != null && routeDetail.isNotEmpty)
                            ? const Color(0xFF334155)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _miniStat(
                          icon: Icons.event_seat_rounded,
                          label: 'السعة',
                          value: driver.capacity != null
                              ? '${driver.capacity} راكب'
                              : '—',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _miniStat(
                          icon: Icons.phone_rounded,
                          label: 'الهاتف',
                          value: (phone != null && phone.isNotEmpty)
                              ? phone
                              : '—',
                          onLongPress: (phone != null && phone.isNotEmpty)
                              ? () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: phone),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم نسخ رقم الهاتف'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoBanner(
                    icon: driver.isStaleWarning
                        ? Icons.schedule_rounded
                        : Icons.update_rounded,
                    color: driver.isStaleWarning
                        ? const Color(0xFFEA580C)
                        : const Color(0xFF16A34A),
                    bg: driver.isStaleWarning
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF0FDF4),
                    border: driver.isStaleWarning
                        ? const Color(0xFFFDBA74)
                        : const Color(0xFFBBF7D0),
                    text: driver.isStaleWarning
                        ? 'آخر تحديث: ${driver.updatedAgoLabel} — قد يكون الموقع غير دقيق'
                        : 'آخر تحديث للموقع: ${driver.updatedAgoLabel}',
                  ),
                  if (widget.onRequestBoard != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _requesting
                            ? null
                            : () async {
                                setState(() => _requesting = true);
                                try {
                                  await widget.onRequestBoard!(driver);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
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
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
