import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/bus_capacity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/trip/eta_utils.dart';
import '../../models/live_driver_location.dart';

/// بطاقة تفاصيل السائق — تصميم فاخر مع ETA بارز وطلب صعود واضح.
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

  Future<void> _callDriver(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
      );
    }
  }

  String get _initial {
    final name = driver.fullName.trim();
    if (name.isEmpty) return 'س';
    return name.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final isTrip = driver.isTripActive;
    final isOnline = driver.isOnline;
    final statusColor = isTrip
        ? const Color(0xFFDC2626)
        : (isOnline ? const Color(0xFF16A34A) : const Color(0xFF6B7280));
    final statusLabel =
        isTrip ? 'في رحلة' : (isOnline ? 'متاح' : 'غير متصل');

    final bus = driver.busNumber?.trim();
    final routeTitle = driver.route?.trim();
    final routeDetail = driver.routeDetail?.trim();
    final phoneRaw = driver.phoneNumber?.trim();
    final String? phone =
        (phoneRaw != null && phoneRaw.isNotEmpty) ? phoneRaw : null;
    final hasPhone = phone != null;

    int? etaMins;
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
      etaMins = EtaUtils.estimateMinutes(
        distanceMeters: meters,
        speedMps: driver.speed,
      );
      distanceText = EtaUtils.formatDistance(meters);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── بطاقة السائق الرئيسية ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // أفاتار + اسم
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accent,
                                  width: 2.5,
                                ),
                                color: _accent.withValues(alpha: 0.08),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initial,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: _accent,
                                ),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
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
                        const SizedBox(height: 16),
                        // شرائح المعلومات
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (driver.capacity != null)
                              _pill(
                                Icons.event_seat_rounded,
                                '${driver.capacity} راكب',
                              ),
                            if (routeTitle != null && routeTitle.isNotEmpty)
                              _pill(Icons.route_rounded, routeTitle),
                            if (bus != null && bus.isNotEmpty)
                              _pill(
                                Icons.confirmation_number_rounded,
                                'كوستر $bus',
                              ),
                          ],
                        ),
                        // ETA بارز
                        if (etaMins != null) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'وقت الوصول المتوقع',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$etaMins',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: _accent,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            'دقائق',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                          if (distanceText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              distanceText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ],
                        // زر طلب الصعود
                        if (widget.onRequestBoard != null) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _requesting
                                  ? null
                                  : () async {
                                      setState(() => _requesting = true);
                                      try {
                                        await widget.onRequestBoard!(driver);
                                        if (!mounted) return;
                                        Navigator.pop(context);
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() => _requesting = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _requesting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'طلب الصعود',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_upward_rounded,
                                            size: 20),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── تفاصيل إضافية ──
                  if (routeDetail != null && routeDetail.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _section(
                      title: 'مسير الخط',
                      icon: Icons.alt_route_rounded,
                      child: Text(
                        routeDetail,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
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
                    text: driver.isStaleWarning
                        ? 'آخر تحديث: ${driver.updatedAgoLabel} — قد يكون غير دقيق'
                        : 'آخر تحديث: ${driver.updatedAgoLabel}',
                  ),

                  if (hasPhone) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _callDriver(phone),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(
                            color: Color(0xFF99F6E4),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.phone_in_talk_rounded),
                        label: const Text(
                          'اتصال بالسائق',
                          style: TextStyle(
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
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
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

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: _accent),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
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

  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
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
