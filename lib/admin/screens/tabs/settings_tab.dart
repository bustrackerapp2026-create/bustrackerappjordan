import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/widgets/pickup_label_size_setting.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/pickup_point_service.dart';
import '../../../services/sample_amman_data_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isMigrating = false;
  bool _isSampleBusy = false;

  static const String _migrationDialogMessage =
      'سيتم ضبط كل النقاط في Firestore:\n'
      '• المعتمدة / القديمة بإحداثيات → status: approved\n'
      '• المعلقة → pending\n'
      '• المرفوضة → rejected\n\n'
      'هل تريد المتابعة؟';

  Future<void> _logout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.logout),
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
              content: Text('❌ $e'),
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
            child: Text(AppLocalizations.of(context).cancel),
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

  Future<void> _importAmmanSample() async {
    if (_isSampleBusy) return;

    final auth = context.read<AuthProvider>();
    final adminId = auth.userId;
    if (adminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول كأدمن'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('عيّنة خط 99 (ملصق على الشوارع)'),
        content: const Text(
          'سيتم:\n'
          '• حذف العيّنة التقريبية القديمة إن وُجدت\n'
          '• استيراد خط 99 ذهاب وإياب من ملفاتك\n'
          '• لصق المسار على شبكة الطرق عبر Mapbox\n'
          '• إضافة 5 نقاط تجمع\n\n'
          'يتطلب إنترنت ومفتاح Mapbox صالح.\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استيراد'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSampleBusy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await SampleAmmanDataService()
          .importSampleIfNeeded(adminId: adminId);
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
          content: Text('❌ فشل الاستيراد: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSampleBusy = false);
    }
  }

  Future<void> _clearAmmanSample() async {
    if (_isSampleBusy) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف عيّنة عمّان'),
        content: const Text(
          'سيتم حذف المسارات ونقاط التجمع الموسومة كعيّنة فقط.\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
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

    setState(() => _isSampleBusy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await SampleAmmanDataService().clearSample();
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
      if (mounted) setState(() => _isSampleBusy = false);
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chooseLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.arabic),
              leading: localeProvider.isArabic
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : const SizedBox(width: 24),
              onTap: () async {
                Navigator.pop(dialogContext);
                await localeProvider.setArabic();
              },
            ),
            ListTile(
              title: Text(l10n.english),
              leading: localeProvider.isEnglish
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : const SizedBox(width: 24),
              onTap: () async {
                Navigator.pop(dialogContext);
                await localeProvider.setEnglish();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userData;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final l10n = AppLocalizations.of(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
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
                              : 'A',
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
                              user?.fullName ?? 'Admin',
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
                  title: Text(
                    l10n.darkMode,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    isDark ? l10n.darkModeOn : l10n.darkModeOff,
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
                  title: Text(
                    l10n.language,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(localeProvider.displayName),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showLanguageDialog(context),
                ),
                const Divider(height: 1),
                const PickupLabelSizeTile(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    l10n.version,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('1.0.0+1'),
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
                  leading: _isSampleBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.map_outlined,
                          color: AppTheme.primaryColor,
                        ),
                  title: const Text(
                    'استيراد خط 99 ملصق على الشوارع',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'ذهاب/إياب من ملفاتك + 5 نقاط · عبر Mapbox Directions',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _isSampleBusy ? null : _importAmmanSample,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'حذف عيّنة عمّان',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'إزالة المسارات والنقاط الموسومة كعيّنة فقط',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _isSampleBusy ? null : _clearAmmanSample,
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
              label: Text(
                l10n.logout,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }
}
