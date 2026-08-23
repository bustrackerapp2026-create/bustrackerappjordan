import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// شريط تنقل عائم للأدمن — رئيسية · نقاط · خريطة · إعدادات
class AdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// عدد طلبات السائقين بانتظار الموافقة — شارة على تبويب الرئيسية
  final int pendingDriverCount;

  const AdminBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.pendingDriverCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;

    final items = <_NavItemData>[
      _NavItemData(
        icon: Icons.verified_user_outlined,
        activeIcon: Icons.verified_user_rounded,
        label: l10n.navHome,
        badgeCount: pendingDriverCount,
      ),
      _NavItemData(
        icon: Icons.location_on_outlined,
        activeIcon: Icons.location_on_rounded,
        label: l10n.navPoints,
      ),
      _NavItemData(
        icon: Icons.map_outlined,
        activeIcon: Icons.map_rounded,
        label: l10n.navMap,
      ),
      _NavItemData(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: l10n.navSettings,
      ),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0.97),
                    ],
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = currentIndex == index;
              final color = selected
                  ? AppTheme.primaryColor
                  : (isDark ? Colors.grey.shade400 : const Color(0xFF5F6368));

              return Expanded(
                child: _NavItem(
                  selected: selected,
                  color: color,
                  icon: selected ? item.activeIcon : item.icon,
                  label: item.label,
                  badgeCount: item.badgeCount,
                  onTap: () {
                    if (index == currentIndex) return;
                    HapticFeedback.selectionClick();
                    onTap(index);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool selected;
  final Color color;
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.selected,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, size: 24, color: color);
    if (badgeCount > 0) {
      final labelText = badgeCount > 99 ? '99+' : '$badgeCount';
      iconWidget = Badge(
        label: Text(
          labelText,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFDC2626),
        child: iconWidget,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: iconWidget,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}
