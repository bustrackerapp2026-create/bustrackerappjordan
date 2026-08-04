import 'package:flutter/material.dart';

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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue.shade700,
      unselectedItemColor: Colors.grey.shade700,
      selectedFontSize: 13,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.verified_user),
          label: 'التحقق', // ✅ تم التعديل من "الرئيسية" إلى "التحقق"
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on),
          label: 'النقاط',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'الخريطة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'الإعدادات',
        ),
      ],
    );
  }
}
