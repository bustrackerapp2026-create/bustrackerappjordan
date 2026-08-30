import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/bus_capacity.dart';
import '../../core/theme/app_theme.dart';
import '../../core/trip/eta_utils.dart';
import '../../models/live_driver_location.dart';

/// بطاقة تفاصيل السائق — التصميم الأصلي قبل إعادة التصميم.
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
      );
    }
  }

  Future<void> _onRequestBoardPressed() async {
    final request = widget.onRequestBoard;
    if (request == null || _requesting) return;
    final navigator = Navigator.of(context);
    setState(() => _requesting = true);
    try {
      await request(driver);
      if (!mounted) return;
      navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _requesting = false);
    }
  }

  String get _initial {
    final name = driver.fullName.trim();
    if (name.isEmpty) return 'س';
    return String.fromCharCode(name.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final dist = (widget.passengerLat != null &&
            widget.passengerLng != null &&
            driver.hasValidCoords)
        ? EtaUtils.distanceMeters(
            widget.passengerLat!,
            widget.passengerLng!,
            driver.latitude,
            driver.longitude,
          )
        : null;

    final statusColor = !driver.hasValidCoords
        ? Colors.grey
        : driver.isStaleWarning
            ? Colors.orange
            : driver.isOnline
                ? Colors.green
                : Colors.grey;
    final statusLabel = !driver.hasValidCoords
        ? 'الموقع غير متاح'
        : driver.isStaleWarning
            ? 'تحديث قديم'
            : driver.isOnline
                ? 'متصل'
                : 'غير متصل';

    return Container(
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _accent.withValues(alpha: 0.15),
                    child: Text(
                      _initial,
                      style: TextStyle(
                        fontSize: 22,
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
                          driver.fullName.trim().isNotEmpty
                              ? driver.fullName.trim()
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (driver.busNumber != null &&
                      driver.busNumber!.trim().isNotEmpty)
                    _chip(Icons.directions_bus, 'باص ${driver.busNumber}'),
                  if (driver.route != null && driver.route!.trim().isNotEmpty)
                    _chip(Icons.route, driver.route!),
                  if (driver.capacity != null)
                    _chip(Icons.people, driver.capacityLabel),
                  _chip(Icons.update, driver.updatedAgoLabel),
                  if (dist != null)
                    _chip(Icons.near_me, EtaUtils.formatDistance(dist)),
                ],
              ),
              const SizedBox(height: 20),
              if (widget.onRequestBoard != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed:
                        _requesting ? null : _onRequestBoardPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _requesting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'طلب صعود',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (driver.phoneNumber != null &&
                  driver.phoneNumber!.trim().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _callDriver(driver.phoneNumber!.trim()),
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصال بالسائق'),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
