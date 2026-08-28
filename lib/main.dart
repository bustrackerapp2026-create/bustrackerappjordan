import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/locale/locale_provider.dart';
import 'core/map/pickup_label_scale_provider.dart';
import 'core/constants/user_roles.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pending_approval_screen.dart';
import 'driver/screens/driver_dashboard.dart';
import 'driver/services/driver_tracking_hub.dart';
import 'passenger/screens/passenger_dashboard.dart';
import 'admin/screens/admin_dashboard.dart';
import 'driver/providers/driver_provider.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics_service.dart';

Future<void> _initDotEnv() async {
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e) {
    debugPrint('⚠️ تحميل .env: $e');
  }

  if (!dotenv.isInitialized) {
    try {
      await dotenv.load(fileName: '.env.example', isOptional: true);
    } catch (e) {
      debugPrint('⚠️ تحميل .env.example: $e');
    }
  }

  if (!dotenv.isInitialized) {
    dotenv.loadFromString(envString: '');
    debugPrint('⚠️ DotEnv: تهيئة فارغة (لا يوجد ملف بيئة)');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('❌ UI error: ${details.exceptionAsString()}');
      debugPrint('${details.stack}');
    }
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Text(
                'حدث خطأ في الواجهة.\nأعد فتح التبويب أو أعد تشغيل التطبيق.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  };

  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 48 << 20;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
    ),
  );

  await _initDotEnv();

  final String? mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
  final hasRealToken = mapboxToken != null &&
      mapboxToken.isNotEmpty &&
      mapboxToken != 'YOUR_MAPBOX_ACCESS_TOKEN_HERE';

  if (hasRealToken) {
    MapboxOptions.setAccessToken(mapboxToken);
    debugPrint('✅ تم تعيين مفتاح Mapbox بنجاح');
  } else {
    debugPrint(
      '❌ تحذير: ضع MAPBOX_ACCESS_TOKEN في ملف .env '
      '(انسخ من .env.example ثم أعد التشغيل)',
    );
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => PickupLabelScaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
      ],
      child: const _DriverAuthBridge(
        child: _AppRoot(),
      ),
    );
  }
}

class _DriverAuthBridge extends StatefulWidget {
  final Widget child;
  const _DriverAuthBridge({required this.child});

  @override
  State<_DriverAuthBridge> createState() => _DriverAuthBridgeState();
}

class _DriverAuthBridgeState extends State<_DriverAuthBridge> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final driver = context.read<DriverProvider>();
      auth.onBeforeSignOut = () {
        unawaited(DriverTrackingHub.instance.shutdown());
        driver.reset();
      };
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, _) {
        return MaterialApp(
          title: 'Bus Tracker Jordan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final isRtl = localeProvider.isArabic;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _cachedType;
  String? _cachedUid;
  String? _loggedRole;

  void _trackRole(String role) {
    if (_loggedRole == role) return;
    _loggedRole = role;
    AnalyticsService().setUserRole(role);
    AnalyticsService().loginSuccess(role);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    if (!isLoggedIn) {
      _cachedType = null;
      _cachedUid = null;
      _loggedRole = null;
      final driver = context.read<DriverProvider>();
      if (driver.isBound || driver.isOnline || driver.isTripActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            unawaited(DriverTrackingHub.instance.shutdown());
            context.read<DriverProvider>().reset();
          }
        });
      }
      return const LoginScreen();
    }

    final snapshot = context.select<
        AuthProvider, ({String? uid, String? type, bool? verified})>((a) {
      final u = a.userData;
      return (
        uid: a.userId,
        type: u?.userType,
        verified: u?.isVerified,
      );
    });

    if (snapshot.uid != null) {
      if (_cachedUid != null && _cachedUid != snapshot.uid) {
        _cachedType = null;
        _loggedRole = null;
        unawaited(DriverTrackingHub.instance.shutdown());
        context.read<DriverProvider>().reset();
      }
      _cachedUid = snapshot.uid;
    }

    if (snapshot.type != null) {
      _cachedType = snapshot.type;
    }

    final type = snapshot.type ?? _cachedType;
    final verified = snapshot.verified == true;

    if (type == null) {
      return const _AuthLoadingScreen();
    }

    if (UserRoles.isAdmin(type)) {
      _trackRole(UserRoles.admin);
      return const AdminDashboard();
    }

    if (UserRoles.isDriverLike(type)) {
      if (snapshot.verified == null && snapshot.type == null) {
        return const _AuthLoadingScreen();
      }
      if (!verified) {
        _trackRole('${type}_pending');
        return const PendingApprovalScreen();
      }
      _trackRole(type);
      return DriverDashboard(
        key: ValueKey('driver_dash_${snapshot.uid ?? _cachedUid}'),
      );
    }

    _trackRole(UserRoles.passenger);
    return const PassengerDashboard();
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                l10n.loadingAccount,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
