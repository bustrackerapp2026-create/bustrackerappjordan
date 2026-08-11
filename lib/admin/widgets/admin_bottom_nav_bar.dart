import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class AdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AdminBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      selectedItemColor: Colors.blue.shade700,
      unselectedItemColor: Colors.grey.shade700,
      selectedFontSize: 13,
      unselectedFontSize: 12,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.verified_user),
          label: l10n.navHome,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.location_on),
          label: l10n.navPoints,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.map),
          label: l10n.navMap,
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings),
          label: l10n.navSettings,
        ),
      ],
    );
  }
}
