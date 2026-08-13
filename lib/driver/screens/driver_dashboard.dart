import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../providers/driver_provider.dart';
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
  /// البدء من تبويب الخريطة
  int _currentIndex = 0;

  final Set<int> _visited = {0};
  final Map<int, Widget> _tabCache = {};

  String? _boundUid;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindDriverSession());
  }

  Future<void> _bindDriverSession() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final driver = context.read<DriverProvider>();
    final uid = auth.userId;

    if (uid == null || uid.isEmpty) {
      driver.reset();
      if (mounted) setState(() => _sessionReady = true);
      return;
    }

    driver.bindToUser(uid);
    _boundUid = uid;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final isOnline = data['isOnline'] == true;
        final isTripActive = data['isTripActive'] == true;
        driver.syncFromRemote(
          userId: uid,
          isOnline: isOnline,
          isTripActive: isTripActive,
        );
      } else {
        driver.syncFromRemote(
          userId: uid,
          isOnline: false,
          isTripActive: false,
        );
      }
    } catch (e) {
      debugPrint('DriverDashboard bind session: $e');
      driver.syncFromRemote(
        userId: uid,
        isOnline: false,
        isTripActive: false,
      );
    }

    if (mounted) setState(() => _sessionReady = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().userId;
    if (uid != null && uid != _boundUid && _sessionReady) {
      _sessionReady = false;
      _bindDriverSession();
    }
  }

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
    if (!_sessionReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const DriverCustomAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        sizing: StackFit.expand,
        children: List.generate(4, (i) {
          if (!_visited.contains(i)) {
            return const ColoredBox(
              color: Colors.transparent,
              child: SizedBox.expand(),
            );
          }
          return KeyedSubtree(
            key: ValueKey('driver_tab_${_boundUid}_$i'),
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
