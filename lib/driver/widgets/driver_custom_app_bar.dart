import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class DriverCustomAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DriverCustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. تحسين الأداء بـ context.select
    final cleanName = context.select<AuthProvider, String>(
      (auth) => auth.userData?.fullName.trim() ?? '',
    );

    // 2. استخدام characters.first للحفاظ على أمان الـ Unicode
    final String initial =
        cleanName.isNotEmpty ? cleanName.characters.first : 'س';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            // استعمل withOpacity إذا كنت تستخدم إصدار Flutter أقل من 3.27
            backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
            radius: 18,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (cleanName.isNotEmpty)
            Text(
              cleanName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppTheme.primaryColor,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📬 سيتم فتح الإشعارات قريباً'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          tooltip: 'الإشعارات',
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: () => _showLogoutDialog(context),
          tooltip: 'تسجيل الخروج',
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    // تجهيز الـ Provider قبل الدخول في الـ Async
    final authProvider = context.read<AuthProvider>();

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
              try {
                await authProvider.signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
