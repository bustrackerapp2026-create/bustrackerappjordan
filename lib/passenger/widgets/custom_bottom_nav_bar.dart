import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
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
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map_rounded),
              label: l10n.navMap,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history_rounded),
              label: l10n.navMyTrips,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.navMyAccount,
            ),
          ],
        ),
      ),
    );
  }
}
