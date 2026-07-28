import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userData;

    // ✅ استخراج الحرف الأول بطريقة آمنة ومعالجة المسافات
    final String cleanName = user?.fullName.trim() ?? '';
    final String initial = cleanName.isNotEmpty ? cleanName[0] : 'ر';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      // ✅ العرض في الجهة اليمنى (مع دعم العربي) لاسم وصورة المستخدم
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
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
      // ✅ وضع الأزرار في الجهة اليسرى (actions) لمنع خطأ الـ Overflow
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppTheme.primaryColor),
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
              Navigator.pop(dialogContext); // إغلاق الديالوج
              // ✅ فقط استدعاء الخروج، والـ AuthWrapper يتكفل فوراً بالتوجيه
              await context.read<AuthProvider>().signOut();
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
