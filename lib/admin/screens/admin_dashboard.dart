import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ مهم للتحكم بشريط الحالة
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'tabs/verify_drivers_tab.dart';
import 'tabs/pending_points_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    VerifyDriversTab(),
    PendingPointsTab(),
    Center(child: Text('📊 الإحصائيات (قيد التطوير)')),
    Center(child: Text('⚙️ الإعدادات (قيد التطوير)')),
  ];

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

    // ✅ الحل النهائي: تغيير لون شريط الحالة إلى الأزرق
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.blue, // ✅ خلفية زرقاء
        statusBarIconBrightness: Brightness.light, // ✅ أيقونات بيضاء
        statusBarBrightness: Brightness.dark, // ✅ للـ iOS
      ),
    );
  }

  @override
  void dispose() {
    // ✅ إعادة ضبط شريط الحالة إلى الافتراضي عند الخروج
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

    return Scaffold(
      // ✅ جعل التطبيق يمتد خلف شريط الحالة (للقضاء على الخلفية السوداء)
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: const Text(
          'لوحة التحكم - المشرف',
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
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade700,
        selectedFontSize: 13,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'التحقق',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'النقاط',
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
