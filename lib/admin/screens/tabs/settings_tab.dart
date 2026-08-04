import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // ✅ حالة وهمية للمظهر (لن نطبقها الآن، لكن نجهز المكان)
  bool _isDarkMode = false;

  // ✅ حالة وهمية للغة
  String _selectedLanguage = 'العربية';

  // ✅ دالة تسجيل الخروج
  Future<void> _logout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // ✅ حوار تأكيد الخروج
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userData;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ============================================
            // ✅ قسم الملف الشخصي (Card مميز)
            // ============================================
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '👑 مشرف',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
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

            // ============================================
            // ✅ قسم الإعدادات
            // ============================================
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // ✅ خيار المظهر
                  SwitchListTile(
                    title: const Text(
                      'الوضع الليلي',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text('تفعيل المظهر الداكن'),
                    value: _isDarkMode,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      // ✅ هنا يمكنك إضافة منطق تغيير الثيم لاحقاً
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔜 سيتم تفعيل الوضع الليلي قريباً'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // ✅ خيار اللغة
                  ListTile(
                    leading: const Icon(Icons.language,
                        color: AppTheme.primaryColor),
                    title: const Text(
                      'اللغة',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(_selectedLanguage),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // ✅ عرض حوار اختيار اللغة
                      _showLanguageDialog(context);
                    },
                  ),
                  const Divider(height: 1),

                  // ✅ خيار عرض الإصدار
                  ListTile(
                    leading: const Icon(Icons.info_outline,
                        color: AppTheme.primaryColor),
                    title: const Text(
                      'الإصدار',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text('1.0.0+1'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📱 الإصدار 1.0.0+1 (آخر تحديث)'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // ✅ خيار إعادة تحميل البيانات
                  ListTile(
                    leading:
                        const Icon(Icons.refresh, color: AppTheme.primaryColor),
                    title: const Text(
                      'تحديث البيانات',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle:
                        const Text('إعادة تحميل جميع البيانات من السيرفر'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔄 جاري تحديث البيانات...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      // ✅ يمكنك هنا إضافة منطق لتحديث الـ Providers
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ============================================
            // ✅ زر تسجيل الخروج (كامل العرض)
            // ============================================
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

            // ✅ نص حقوق النشر في الأسفل
            Center(
              child: Text(
                '© 2026 Bus Tracker Jordan - جميع الحقوق محفوظة',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ دالة عرض حوار اختيار اللغة
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🌐 تم تغيير اللغة إلى العربية'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('English'),
              leading: Icon(Icons.check,
                  color: _selectedLanguage == 'English'
                      ? AppTheme.primaryColor
                      : Colors.transparent),
              onTap: () {
                setState(() => _selectedLanguage = 'English');
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🌐 Language changed to English'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
