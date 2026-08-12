import 'package:flutter/material.dart';
import '../widgets/driver_custom_app_bar.dart';
import '../widgets/driver_custom_bottom_nav_bar.dart';
import 'tabs/driver_map_tab.dart';
import 'tabs/operations_tab.dart';
import 'tabs/bookings_tab.dart';
import 'tabs/profile_tab.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;

  /// لا تُنشأ الخريطة وبقية التبويبات دفعة واحدة — يقلل التعطّل عند الدخول
  final Set<int> _visited = {0};
  final Map<int, Widget> _tabCache = {};

  Widget _tabFor(int index) {
    return _tabCache.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return const DriverMapTab();
        case 1:
          return const OperationsTab();
        case 2:
          return const BookingsTab();
        case 3:
          return const ProfileTab();
        default:
          return const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DriverCustomAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        sizing: StackFit.expand,
        children: List.generate(4, (i) {
          if (!_visited.contains(i)) {
            return const SizedBox.shrink();
          }
          return KeyedSubtree(
            key: ValueKey('driver_tab_$i'),
            child: _tabFor(i),
          );
        }),
      ),
      bottomNavigationBar: DriverCustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() {
            _visited.add(index);
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
