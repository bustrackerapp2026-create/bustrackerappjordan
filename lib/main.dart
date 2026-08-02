import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'core/theme/app_theme.dart';
import 'core/constants/user_roles.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pending_approval_screen.dart';
import 'driver/screens/driver_dashboard.dart';
import 'passenger/screens/passenger_dashboard.dart';
import 'admin/screens/admin_dashboard.dart';
import 'driver/providers/driver_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ جعل شريط النظام (Status Bar) شفافاً ومتناسقاً لمنع ظهور البار الأسود المزعج
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          Brightness.dark, // أيقونات داكنة واضحة (ساعة، شبكة، بطارية)
      systemNavigationBarColor: Colors.white,
    ),
  );

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('⚠️ لم يتم العثور على ملف .env: $e');
  }

  final String? mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];

  if (mapboxToken != null && mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
    debugPrint('✅ تم تعيين مفتاح Mapbox بنجاح');
  } else {
    debugPrint(
        '❌ تحذير أمني: لم يتم العثور على MAPBOX_ACCESS_TOKEN في ملف .env');
  }

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
        ChangeNotifierProvider(create: (_) => DriverProvider()),
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

    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    if (authProvider.userData == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'جاري تحميل بيانات الحساب...',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.read<AuthProvider>().signOut(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .error, // ✅ استخدام لون الثيم
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userData = authProvider.userData!;

    if (userData.userType == UserRoles.admin) {
      return const AdminDashboard();
    }

    if (userData.userType == UserRoles.driver) {
      if (!userData.isVerified) {
        return const PendingApprovalScreen();
      }
      return const DriverDashboard();
    }

    return const PassengerDashboard();
  }
}
