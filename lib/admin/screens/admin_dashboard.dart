import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/app_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
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

  final FirestoreService _firestore = FirestoreService();
  StreamSubscription<int>? _pendingSub;
  int _pendingDrivers = 0;

  late final Widget _verifyTab = const VerifyDriversTab();
  late final Widget _settingsTab = const SettingsTab();
  late final Widget _pendingTab = PendingPointsTab(onShowOnMap: _showPointOnMap);

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

    // شارة حية لطلبات السائقين بانتظار الموافقة
    _pendingSub = _firestore.watchPendingDriverApprovals().listen(
      (count) {
        if (!mounted) return;
        if (_pendingDrivers != count) {
          setState(() => _pendingDrivers = count);
        }
      },
      onError: (e) {
        debugPrint('AdminDashboard pending stream: $e');
      },
    );
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _pendingSub = null;
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
    final l10n = AppLocalizations.of(context);

    final tabs = <Widget>[
      _verifyTab,
      _pendingTab,
      AdminMapTab(focusRequest: _mapFocus),
      _settingsTab,
    ];

    return Scaffold(
      appBar: AppTopBar.admin(title: l10n.adminDashboardTitle),
      body: Column(
        children: [
          // شريط تنبيه أعلى لوحة الأدمن عند وجود طلبات معلّقة
          if (_pendingDrivers > 0 && _currentIndex != 0)
            Material(
              color: const Color(0xFFFFF7ED),
              child: InkWell(
                onTap: () => setState(() => _currentIndex = 0),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 18,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pendingDrivers == 1
                              ? 'يوجد طلب سائق واحد بانتظار الموافقة'
                              : 'يوجد $_pendingDrivers طلبات سائقين بانتظار الموافقة',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFFEA580C),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AdminBottomNavBar(
        currentIndex: _currentIndex,
        pendingDriverCount: _pendingDrivers,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
