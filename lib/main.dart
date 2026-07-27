import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'driver/screens/driver_dashboard.dart';
import 'passenger/screens/passenger_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BusTrackerApp());
}

class BusTrackerApp extends StatelessWidget {
  const BusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Bus Tracker Jordan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

// ============================================================
// ✅ بوابة المصادقة الذكية (AuthWrapper)
// ============================================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // 1️⃣ إذا لم يكن مسجلاً دخولاً
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    // 2️⃣ جاري تحميل بيانات المستخدم من Firestore
    if (authProvider.userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userData = authProvider.userData!;

    // 3️⃣ إذا كان سائقاً
    if (userData.userType == 'driver') {
      // ✅ فحص التوثيق: إذا لم يُفعّل حساب السائق بعد
      if (!userData.isVerified) {
        return const PendingApprovalScreen();
      }
      return const DriverDashboard();
    }

    // 4️⃣ الراكب (افتراضي)
    return const PassengerDashboard();
  }
}

// ============================================================
// ✅ شاشة انتظار موافقة الإدارة للسائق (تم تصحيح الأيقونة والـ const)
// ============================================================
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ تم تصحيح اسم الأيقونة إلى hourglass_top_rounded
            const Icon(
              Icons.hourglass_top_rounded,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              'حسابك قيد المراجعة',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'تم إنشاء حساب السائق بنجاح، وسيتم تفعيله من قبل الإدارة بعد التأكد من البيانات.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}
