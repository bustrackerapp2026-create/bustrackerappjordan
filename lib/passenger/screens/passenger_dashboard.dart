import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart'; // ✅ استيراد الـ CustomAppBar
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
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    MapTab(),
    TripsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ ربط CustomAppBar المخصص للراكب
      appBar: const CustomAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
