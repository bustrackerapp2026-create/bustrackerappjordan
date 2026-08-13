import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          elevation: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          selectedIndex: currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if (index == currentIndex) return;
            HapticFeedback.selectionClick();
            onTap(index);
          },
          destinations: [
            NavigationDestination(
              icon: _badgedIcon(
                Icons.verified_user_outlined,
                pendingDriverCount,
              ),
              selectedIcon: _badgedIcon(
                Icons.verified_user_rounded,
                pendingDriverCount,
              ),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.location_on_outlined),
              selectedIcon: const Icon(Icons.location_on_rounded),
              label: l10n.navPoints,
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map_rounded),
              label: l10n.navMap,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgedIcon(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    final label = count > 99 ? '99+' : '$count';
    return Badge(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: const Color(0xFFDC2626),
      child: Icon(icon),
    );
  }
}
