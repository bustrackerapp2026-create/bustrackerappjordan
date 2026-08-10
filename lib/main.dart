import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'firebase_options.dart';
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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await firestore.FirebaseFirestore.instance.enableNetwork();
  firestore.FirebaseFirestore.instance.settings =
      const firestore.Settings(persistenceEnabled: true);

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
        // يقلل إعادة بناء غير ضرورية عند تغيير لوحة المفاتيح/الحواف
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

/// بوابة مصادقة تعيد البناء فقط عند تغيّر حالة الدخول أو الدور
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    if (!isLoggedIn) {
      return const LoginScreen();
    }

    // نختار فقط الحقول المؤثرة على التوجيه — لا نُعيد بناء عند أي notify عابر
    final gate = context.select<AuthProvider, ({String? type, bool? verified})>(
      (a) {
        final u = a.userData;
        if (u == null) return (type: null, verified: null);
        return (type: u.userType, verified: u.isVerified);
      },
    );

    if (gate.type == null) {
      return const _AuthLoadingScreen();
    }

    if (gate.type == UserRoles.admin) {
      return const AdminDashboard();
    }

    if (gate.type == UserRoles.driver) {
      if (gate.verified != true) {
        return const PendingApprovalScreen();
      }
      return const DriverDashboard();
    }

    return const PassengerDashboard();
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: Theme.of(context).colorScheme.error,
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
}
