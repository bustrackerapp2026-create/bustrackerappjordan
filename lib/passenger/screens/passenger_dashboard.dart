import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'tabs/map_tab.dart';
import 'tabs/trips_tab.dart';
import 'tabs/profile_tab.dart';

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  /// 0 خريطة · 1 رحلات · 2 حساب
  int _currentIndex = 0;

  /// كاش للتبويبات غير الخريطة فقط — لا نُبقي Mapbox في الشجرة.
  final Map<int, Widget> _nonMapCache = {};

  Widget _nonMapTab(int index) {
    return _nonMapCache.putIfAbsent(index, () {
      switch (index) {
        case 1:
          return const TripsTab();
        case 2:
          return const ProfileTab();
        default:
          return const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // مهم: لا IndexedStack للخريطة — يحرّر Mapbox عند مغادرة التبويب.
    final Widget body;
    if (_currentIndex == 0) {
      body = const MapTab(key: ValueKey('passenger_map'));
    } else {
      body = KeyedSubtree(
        key: ValueKey('passenger_tab_$_currentIndex'),
        child: _nonMapTab(_currentIndex),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: body,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
