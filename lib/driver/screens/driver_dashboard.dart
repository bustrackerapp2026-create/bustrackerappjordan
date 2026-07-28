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

  final List<Widget> _tabs = const [
    DriverMapTab(),
    OperationsTab(),
    BookingsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DriverCustomAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: DriverCustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
