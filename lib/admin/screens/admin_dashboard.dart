import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'tabs/verify_drivers_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    VerifyDriversTab(),
    Center(child: Text('📊 الإحصائيات (قيد التطوير)')),
    Center(child: Text('⚙️ الإعدادات (قيد التطوير)')),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم - المشرف'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authProvider.signOut();
              // AuthWrapper سيتكفل بالتوجيه إلى شاشة تسجيل الدخول
            },
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blue.shade700,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'التحقق',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'إحصائيات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'إعدادات',
          ),
        ],
      ),
    );
  }
}
