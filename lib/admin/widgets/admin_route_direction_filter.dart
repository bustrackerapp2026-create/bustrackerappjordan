import 'package:flutter/material.dart';

/// وضع عرض مسارات plannedRoutes على خريطة الأدمن.
enum AdminRouteDirectionFilter {
  /// ذهاب + إياب
  all,

  /// ذهاب فقط
  outbound,

  /// إياب فقط
  returnTrip,
}

extension AdminRouteDirectionFilterX on AdminRouteDirectionFilter {
  String get labelAr {
    switch (this) {
      case AdminRouteDirectionFilter.all:
        return 'الكل';
      case AdminRouteDirectionFilter.outbound:
        return 'ذهاب';
      case AdminRouteDirectionFilter.returnTrip:
        return 'إياب';
    }
  }

  String get shortHint {
    switch (this) {
      case AdminRouteDirectionFilter.all:
        return 'عرض كل المسارات';
      case AdminRouteDirectionFilter.outbound:
        return 'مسارات الذهاب فقط';
      case AdminRouteDirectionFilter.returnTrip:
        return 'مسارات الإياب فقط';
    }
  }

  Color get accent {
    switch (this) {
      case AdminRouteDirectionFilter.all:
        return const Color(0xFF0D9488);
      case AdminRouteDirectionFilter.outbound:
        return const Color(0xFF1D8FE1);
      case AdminRouteDirectionFilter.returnTrip:
        return const Color(0xFF0E9F5D);
    }
  }

  IconData get icon {
    switch (this) {
      case AdminRouteDirectionFilter.all:
        return Icons.route_rounded;
      case AdminRouteDirectionFilter.outbound:
        return Icons.arrow_upward_rounded;
      case AdminRouteDirectionFilter.returnTrip:
        return Icons.arrow_downward_rounded;
    }
  }
}

/// شريط اختيار: الكل | ذهاب | إياب
class AdminRouteDirectionFilterBar extends StatelessWidget {
  final AdminRouteDirectionFilter value;
  final ValueChanged<AdminRouteDirectionFilter> onChanged;
  final int outboundCount;
  final int returnCount;

  const AdminRouteDirectionFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.outboundCount = 0,
    this.returnCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(
              filter: AdminRouteDirectionFilter.all,
              selected: value == AdminRouteDirectionFilter.all,
              badge: outboundCount + returnCount,
              onTap: () => onChanged(AdminRouteDirectionFilter.all),
            ),
            const SizedBox(width: 4),
            _Chip(
              filter: AdminRouteDirectionFilter.outbound,
              selected: value == AdminRouteDirectionFilter.outbound,
              badge: outboundCount,
              onTap: () => onChanged(AdminRouteDirectionFilter.outbound),
            ),
            const SizedBox(width: 4),
            _Chip(
              filter: AdminRouteDirectionFilter.returnTrip,
              selected: value == AdminRouteDirectionFilter.returnTrip,
              badge: returnCount,
              onTap: () => onChanged(AdminRouteDirectionFilter.returnTrip),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final AdminRouteDirectionFilter filter;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _Chip({
    required this.filter,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = filter.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter.icon,
              size: 16,
              color: selected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              filter.labelAr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? color : Colors.grey.shade800,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
