import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/app_top_bar.dart';
import 'tabs/verify_drivers_tab.dart';
import 'tabs/pending_points_tab.dart';
import 'tabs/admin_map_tab.dart';
import 'tabs/settings_tab.dart';
import '../widgets/admin_bottom_nav_bar.dart';

/// طلب انتقال الكاميرا على خريطة الأدمن إلى نقطة معينة
class AdminMapFocusRequest {
  final double latitude;
  final double longitude;
  final String pointName;
  final String? pointId;
  final int token;

  const AdminMapFocusRequest({
    required this.latitude,
    required this.longitude,
    required this.pointName,
    this.pointId,
    required this.token,
  });
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  AdminMapFocusRequest? _mapFocus;
  int _focusToken = 0;

  void _showPointOnMap({
    required double latitude,
    required double longitude,
    required String pointName,
    String? pointId,
  }) {
    setState(() {
      _focusToken++;
      _mapFocus = AdminMapFocusRequest(
        latitude: latitude,
        longitude: longitude,
        pointName: pointName,
        pointId: pointId,
        token: _focusToken,
      );
      _currentIndex = 2;
    });
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.blue,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const VerifyDriversTab(),
      PendingPointsTab(onShowOnMap: _showPointOnMap),
      AdminMapTab(focusRequest: _mapFocus),
      const SettingsTab(),
    ];

    return Scaffold(
      appBar: AppTopBar.admin(title: 'لوحة التحكم - الأدمن'),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: AdminBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
