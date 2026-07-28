import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DriverCustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const DriverCustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 13,
      unselectedFontSize: 12,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map),
          label: 'الخريطة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'العمليات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'الطلبات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outlined),
          activeIcon: Icon(Icons.person),
          label: 'حسابي',
        ),
      ],
    );
  }
}
