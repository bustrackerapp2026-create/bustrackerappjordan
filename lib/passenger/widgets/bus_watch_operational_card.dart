import 'package:flutter/material.dart';

import '../../models/live_driver_location.dart';
import '../../models/planned_route.dart';
import '../../services/bus_watch_operational_read_result.dart';

/// عرض Passenger-only لنتيجة BusWatch التشغيلية الحالية.
///
/// لا يدير قراءة أو lifecycle أو cache؛ يستقبل الحالة الجاهزة من MapTab.
class BusWatchOperationalCard extends StatelessWidget {
  final bool loading;
  final BusWatchOperationalReadResult? result;
  final Object? error;
  final VoidCallback? onRetry;

  const BusWatchOperationalCard({
    super.key,
    required this.loading,
    required this.result,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (result?.status ==
        BusWatchOperationalReadStatus.noPassengerContext) {
      return const SizedBox.shrink();
    }

    if (loading && result == null && error == null) {
      return _CardShell(
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'جارٍ تحميل معلومات الحافلة...',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    if (error != null && result == null) {
      return _CardShell(
        child: _MessageState(
          icon: Icons.error_outline_rounded,
          title: 'تعذر تحديث معلومات الحافلة',
          subtitle: 'تحقق من الاتصال ثم أعد المحاولة.',
          onRetry: loading ? null : onRetry,
        ),
      );
    }

    final current = result;
    if (current == null) return const SizedBox.shrink();

    switch (current.status) {
      case BusWatchOperationalReadStatus.available:
        final snapshot = current.snapshot;
        if (snapshot == null) return const SizedBox.shrink();
        return _buildAvailable(snapshot);

      case BusWatchOperationalReadStatus.noActiveVehicleTrip:
        return _MessageCard(
          icon: Icons.directions_bus_outlined,
          title: 'لا توجد رحلة تشغيلية نشطة للحافلة حاليًا',
        );

      case BusWatchOperationalReadStatus.noLiveLocation:
        return _MessageCard(
          icon: Icons.location_off_outlined,
          title: 'الرحلة التشغيلية موجودة، لكن موقع الحافلة غير متاح حاليًا',
        );

      case BusWatchOperationalReadStatus.noApprovedRoute:
        return _MessageCard(
          icon: Icons.route_outlined,
          title: 'تعذر تحميل المسار المعتمد للحافلة حاليًا',
        );

      case BusWatchOperationalReadStatus.noPassengerContext:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAvailable(BusWatchOperationalSnapshot snapshot) {
    final driverName = snapshot.liveLocation.fullName.trim().isEmpty
        ? 'السائق'
        : snapshot.liveLocation.fullName.trim();
    final busNumber = snapshot.busNumber.trim();
    final lineName = snapshot.approvedRoute.lineName.trim();
    final direction = snapshot.direction == 'return' ? 'إياب' : 'ذهاب';

    return _CardShell(
      accent: const Color(0xFF0F766E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_bus_filled_rounded,
                color: Color(0xFF0F766E),
                size: 21,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'الحافلة في رحلة نشطة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (busNumber.isNotEmpty) _InfoChip('باص $busNumber'),
              if (lineName.isNotEmpty) _InfoChip(lineName),
              _InfoChip(direction),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            driverName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _MessageCard({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: const Color(0xFFB91C1C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text(
              'إعادة المحاولة',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;

  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F766E),
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  final Color accent;

  const _CardShell({
    required this.child,
    this.accent = const Color(0xFF64748B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
