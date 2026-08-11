import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/pickup_point_service.dart';
import '../../../services/route_seed_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _selectedLanguage = 'العربية';
  bool _isMigrating = false;
  bool _isSeedingRoutes = false;

  static const String _migrationDialogMessage =
      'سيتم ضبط كل النقاط في Firestore:\n'
      '• المعتمدة / القديمة بإحداثيات → status: approved\n'
      '• المعلقة → pending\n'
      '• المرفوضة → rejected\n\n'
      'هل تريد المتابعة؟';

  Future<void> _logout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await authProvider.signOut();
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('❌ حدث خطأ أثناء تسجيل الخروج: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _runStatusMigration() async {
    if (_isMigrating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('توحيد حالات النقاط'),
        content: const Text(_migrationDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تنفيذ'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isMigrating = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await PickupPointService().migrateNormalizeStatuses();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ تم التوحيد\n$result'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ فشل الترحيل: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  Future<void> _seedDemoRoutes() async {
    if (_isSeedingRoutes) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زرع مسارات تجريبية'),
        content: const Text(
          'سيتم إضافة 8 مسارات بين محافظات الأردن مع محطات وإحداثيات:\n\n'
          '• عمان — إربد\n'
          '• عمان — العقبة\n'
          '• عمان — الزرقاء\n'
          '• عمان — الكرك\n'
          '• عمان — جرش\n'
          '• الزرقاء — المفرق\n'
          '• إربد — المفرق\n'
          '• عمان — مادبا\n\n'
          'تظهر على خريطة الأدمن كخطوط ملوّنة.\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('زرع المسارات'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSeedingRoutes = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await RouteSeedService().seedJordanDemoRoutes();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ $result'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ فشل الزرع: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSeedingRoutes = false);
    }
  }

  Future<void> _clearDemoRoutes() async {
    if (_isSeedingRoutes) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المسارات التجريبية'),
        content: const Text(
          'سيتم حذف كل المسارات التي وُسمت كتجريبية (isDemo) مع محطاتها وإحداثياتها.\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSeedingRoutes = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await RouteSeedService().clearDemoRoutes();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ $result'),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ فشل الحذف: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSeedingRoutes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userData;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName[0]
                                : 'أ',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'الأدمن',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? 'admin@example.com',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.blue.shade900.withValues(alpha: 0.4)
                                      : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '👑 مشرف',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.blue.shade200
                                        : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text(
                      'الوضع الليلي',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      isDark ? 'المظهر الداكن مفعّل' : 'تفعيل المظهر الداكن',
                    ),
                    value: isDark,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      context.read<ThemeProvider>().setDarkMode(value);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text(
                      'اللغة',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(_selectedLanguage),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showLanguageDialog(context),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'الإصدار',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('1.0.0+1'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _isMigrating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.sync_problem,
                            color: AppTheme.primaryColor,
                          ),
                    title: const Text(
                      'توحيد حالات النقاط (status)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'ضبط كل النقاط المعتمدة إلى status: approved',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _isMigrating ? null : _runStatusMigration,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _isSeedingRoutes
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.route,
                            color: AppTheme.primaryColor,
                          ),
                    title: const Text(
                      'زرع مسارات تجريبية (الأردن)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      '8 خطوط بين المحافظات للتجربة على الخريطة',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _isSeedingRoutes ? null : _seedDemoRoutes,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'حذف المسارات التجريبية',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'إزالة المسارات الموسومة isDemo فقط',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _isSeedingRoutes ? null : _clearDemoRoutes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '© 2026 Bus Tracker Jordan - جميع الحقوق محفوظة',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اختر اللغة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('العربية'),
              leading: const Icon(Icons.check, color: AppTheme.primaryColor),
              onTap: () {
                setState(() => _selectedLanguage = 'العربية');
                Navigator.pop(dialogContext);
              },
            ),
            ListTile(
              title: const Text('English'),
              onTap: () {
                setState(() => _selectedLanguage = 'English');
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}
