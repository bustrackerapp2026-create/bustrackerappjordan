import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// شريط تنقل عائم بزوايا دائرية — مظهر أحدث لشاشة الراكب.
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
    final surface = isDark ? AppTheme.darkSurface : Colors.white;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Material(
          color: surface,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            height: 64,
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.14),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
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
                selectedIcon: Icon(
                  Icons.map_rounded,
                  color: AppTheme.primaryColor,
                ),
                label: l10n.navMap,
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: Icon(
                  Icons.history_rounded,
                  color: AppTheme.primaryColor,
                ),
                label: l10n.navMyTrips,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryColor,
                ),
                label: l10n.navMyAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
