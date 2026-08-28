import 'package:flutter/material.dart';

import '../../core/trip/eta_utils.dart';
import '../../models/live_driver_location.dart';

/// بطاقة معلومات الباص — Bottom Sheet مختصرة فوق الخريطة.
class DriverDetailsSheet extends StatefulWidget {
  final LiveDriverLocation driver;
  final double? passengerLat;
  final double? passengerLng;
  final Future<void> Function(LiveDriverLocation driver)? onRequestBoard;
  final void Function(LiveDriverLocation driver)? onFollowBus;

  const DriverDetailsSheet({
    super.key,
    required this.driver,
    this.passengerLat,
    this.passengerLng,
    this.onRequestBoard,
    this.onFollowBus,
  });

  @override
  State<DriverDetailsSheet> createState() => _DriverDetailsSheetState();
}

class _DriverDetailsSheetState extends State<DriverDetailsSheet> {
  bool _requesting = false;
  bool _expanded = false;

  LiveDriverLocation get driver => widget.driver;

  static const _primary = Color(0xFF2563EB);
  static const _textMain = Color(0xFF172033);
  static const _textSec = Color(0xFF64748B);

  double? get _distanceMeters {
    final plat = widget.passengerLat;
    final plng = widget.passengerLng;
    if (plat == null || plng == null || !driver.hasValidCoords) return null;
    return EtaUtils.distanceMeters(
      plat, plng, driver.latitude, driver.longitude,
    );
  }

  _BusUiStatus get _status {
    if (!driver.hasValidCoords) return _BusUiStatus.noLocation;
    if (!driver.isOnline) return _BusUiStatus.offline;
    if (driver.isStaleWarning || !driver.isFresh) return _BusUiStatus.stale;
    final speed = driver.speed;
    if (speed != null && speed.isFinite && speed < 0.8) {
      return _BusUiStatus.stopped;
    }
    return _BusUiStatus.moving;
  }

  String get _busTitle {
    final bus = driver.busNumber?.trim();
    if (bus != null && bus.isNotEmpty) return 'باص $bus';
    return driver.displayLabel;
  }

  String get _lineName {
    final detail = driver.routeDetail?.trim();
    if (detail != null && detail.isNotEmpty) return detail;
    final route = driver.route?.trim();
    if (route != null && route.isNotEmpty) return route;
    return 'خط غير محدد';
  }

  String? get _headingText {
    final h = driver.heading;
    if (h == null || !h.isFinite) return null;
    final deg = ((h % 360) + 360) % 360;
    if (deg >= 337.5 || deg < 22.5) return 'يتجه شمالاً';
    if (deg < 67.5) return 'يتجه شمالاً شرقياً';
    if (deg < 112.5) return 'يتجه شرقاً';
    if (deg < 157.5) return 'يتجه جنوباً شرقياً';
    if (deg < 202.5) return 'يتجه جنوباً';
    if (deg < 247.5) return 'يتجه جنوباً غربياً';
    if (deg < 292.5) return 'يتجه غرباً';
    return 'يتجه شمالاً غربياً';
  }

  String get _updatedLabel {
    final at = driver.updatedAt;
    if (at == null) return 'وقت التحديث غير معروف';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 15) return 'منذ لحظات';
    if (diff.inSeconds < 60) return 'منذ ${diff.inSeconds} ثانية';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  void _follow() {
    final cb = widget.onFollowBus;
    Navigator.of(context).pop();
    cb?.call(driver);
  }

  Future<void> _requestBoard() async {
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final status = _status;
    final dist = _distanceMeters;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  onVerticalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -200) setState(() => _expanded = true);
                    else if (v > 200) {
                      if (_expanded) {
                        setState(() => _expanded = false);
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        color: _primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _busTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _textMain,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _lineName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textSec,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.update_rounded,
                        label: 'آخر تحديث',
                        value: _updatedLabel,
                        accent: status.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.near_me_rounded,
                        label: 'المسافة منك',
                        value: dist == null
                            ? '—'
                            : EtaUtils.formatDistance(dist),
                        accent: _primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(status.icon, size: 18, color: status.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status.detailText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: status.color,
                          ),
                        ),
                      ),
                      if (_headingText != null)
                        Text(
                          _headingText!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSec,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (status == _BusUiStatus.stale) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'قد تكون بيانات الموقع غير محدّثة',
                    style: TextStyle(fontSize: 12, color: _textSec),
                  ),
                ],
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: _ExpandedSection(driver: driver),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: driver.hasValidCoords ? _follow : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 20),
                    label: const Text('متابعة الباص'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.onRequestBoard != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _requesting ? null : _requestBoard,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textMain,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _requesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2),
                                )
                              : const Text('طلب صعود'),
                        ),
                      ),
                    if (widget.onRequestBoard != null)
                      const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: _textSec,
                          minimumSize: const Size(0, 46),
                        ),
                        child: const Text('إغلاق'),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        foregroundColor: _primary,
                        minimumSize: const Size(0, 46),
                      ),
                      child: Text(_expanded ? 'أقل' : 'المزيد'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BusUiStatus { moving, stopped, stale, offline, noLocation }

extension on _BusUiStatus {
  Color get color {
    switch (this) {
      case _BusUiStatus.moving:
        return const Color(0xFF16A34A);
      case _BusUiStatus.stopped:
      case _BusUiStatus.stale:
        return const Color(0xFFF59E0B);
      case _BusUiStatus.offline:
      case _BusUiStatus.noLocation:
        return const Color(0xFF94A3B8);
    }
  }

  String get label {
    switch (this) {
      case _BusUiStatus.moving:
        return 'متصل الآن';
      case _BusUiStatus.stopped:
        return 'متوقف مؤقتاً';
      case _BusUiStatus.stale:
        return 'تحديث قديم';
      case _BusUiStatus.offline:
        return 'غير متصل';
      case _BusUiStatus.noLocation:
        return 'الموقع غير متاح';
    }
  }

  String get detailText {
    switch (this) {
      case _BusUiStatus.moving:
        return 'يتحرك الآن';
      case _BusUiStatus.stopped:
        return 'متوقف مؤقتاً';
      case _BusUiStatus.stale:
        return 'آخر تحديث قديم — قد تكون البيانات غير دقيقة';
      case _BusUiStatus.offline:
        return 'الباص غير متصل حالياً';
      case _BusUiStatus.noLocation:
        return 'لا تتوفر إحداثيات لهذا الباص';
    }
  }

  IconData get icon {
    switch (this) {
      case _BusUiStatus.moving:
        return Icons.directions_bus_filled_rounded;
      case _BusUiStatus.stopped:
        return Icons.pause_circle_filled_rounded;
      case _BusUiStatus.stale:
        return Icons.schedule_rounded;
      case _BusUiStatus.offline:
        return Icons.cloud_off_rounded;
      case _BusUiStatus.noLocation:
        return Icons.location_off_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final _BusUiStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExpandedSection extends StatelessWidget {
  final LiveDriverLocation driver;
  const _ExpandedSection({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          const Text(
            'تفاصيل إضافية',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 8),
          _row('نوع المركبة', driver.capacityLabel),
          if (driver.fullName.trim().isNotEmpty)
            _row('السائق', driver.fullName.trim()),
          if (driver.speed != null &&
              driver.speed!.isFinite &&
              driver.speed! > 0)
            _row(
              'السرعة التقريبية',
              '${(driver.speed! * 3.6).toStringAsFixed(0)} كم/س',
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF172033),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
