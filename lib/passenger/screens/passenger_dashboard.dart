import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/route_prefs_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'passenger_onboarding_screen.dart';
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
  int _mapGeneration = 0;

  bool _loadingOnboarding = true;
  bool _showOnboarding = false;

  final Map<int, Widget> _nonMapCache = {};

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final done = await RoutePrefsService().hasCompletedOnboarding();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !done;
      _loadingOnboarding = false;
    });
  }

  void _finishOnboarding() {
    setState(() {
      _showOnboarding = false;
      _mapGeneration++;
      _currentIndex = 0;
    });
  }

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
    if (_loadingOnboarding) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_showOnboarding) {
      return PassengerOnboardingScreen(onFinished: _finishOnboarding);
    }

    final Widget body;
    if (_currentIndex == 0) {
      body = MapTab(key: ValueKey('passenger_map_$_mapGeneration'));
    } else {
      body = KeyedSubtree(
        key: ValueKey('passenger_tab_$_currentIndex'),
        child: _nonMapTab(_currentIndex),
      );
    }

    return Scaffold(
      extendBody: _currentIndex == 0,
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
