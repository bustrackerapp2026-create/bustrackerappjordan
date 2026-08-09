import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
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
  final int token; // لتكرار نفس الإحداثيات يُحدّث الواجهة

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
      _currentIndex = 2; // تبويب الخريطة
    });
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );
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
    final authProvider = context.watch<AuthProvider>();

    final tabs = [
      const VerifyDriversTab(),
      PendingPointsTab(onShowOnMap: _showPointOnMap),
      AdminMapTab(focusRequest: _mapFocus),
      const SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة التحكم - الأدمن',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: kToolbarHeight,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _showLogoutDialog(context, authProvider),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
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
