import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

/// نمط مظهر الشريط العلوي
enum AppTopBarStyle {
  /// خلفية بيضاء ونص داكن (راكب / سائق)
  light,

  /// خلفية اللون الأساسي ونص أبيض (أدمن / شاشات النظام)
  primary,
}

/// الشريط العلوي الموحّد للتطبيق — يُستخدم في كل الشاشات.
///
/// مثال:
/// ```dart
/// appBar: AppTopBar(
///   title: 'لوحة الراكب',
///   showUserName: true,
///   showNotifications: true,
///   showLogout: true,
/// )
/// ```
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// عنوان نصي (يُتجاهل إذا وُجد [titleWidget] أو [showUserName] بدون عنوان)
  final String? title;

  /// عنوان مخصص بالكامل
  final Widget? titleWidget;

  /// عرض اسم المستخدم + الحرف الأول
  final bool showUserName;

  /// الحرف الافتراضي إذا لم يتوفر اسم
  final String fallbackInitial;

  /// زر الإشعارات
  final bool showNotifications;

  /// زر تسجيل الخروج
  final bool showLogout;

  /// أزرار إضافية على اليمين (قبل الإشعارات/الخروج)
  final List<Widget>? actions;

  /// ويدجت على اليسار (مثل زر رجوع)
  final Widget? leading;

  /// إظهار زر الرجوع تلقائياً إن أمكن
  final bool automaticallyImplyLeading;

  /// توسيط العنوان
  final bool centerTitle;

  /// مظهر الشريط
  final AppTopBarStyle style;

  /// ارتفاع اختياري
  final double height;

  /// ظل خفيف
  final double elevation;

  /// عند الضغط على الإشعارات (افتراضي: رسالة قريباً)
  final VoidCallback? onNotificationsTap;

  /// عند تأكيد الخروج بعد الحوار (اختياري — الافتراضي signOut)
  final Future<void> Function()? onLogoutConfirmed;

  const AppTopBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showUserName = false,
    this.fallbackInitial = 'م',
    this.showNotifications = false,
    this.showLogout = false,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.style = AppTopBarStyle.light,
    this.height = kToolbarHeight,
    this.elevation = 1,
    this.onNotificationsTap,
    this.onLogoutConfirmed,
  });

  /// اختصار شائع للراكب/السائق
  factory AppTopBar.user({
    Key? key,
    String fallbackInitial = 'م',
    List<Widget>? actions,
    VoidCallback? onNotificationsTap,
  }) {
    return AppTopBar(
      key: key,
      showUserName: true,
      fallbackInitial: fallbackInitial,
      showNotifications: true,
      showLogout: true,
      actions: actions,
      onNotificationsTap: onNotificationsTap,
      style: AppTopBarStyle.light,
      centerTitle: false,
    );
  }

  /// اختصار شائع للأدمن
  factory AppTopBar.admin({
    Key? key,
    String title = 'لوحة التحكم - الأدمن',
    List<Widget>? actions,
  }) {
    return AppTopBar(
      key: key,
      title: title,
      showLogout: true,
      showNotifications: false,
      actions: actions,
      style: AppTopBarStyle.primary,
      centerTitle: true,
      elevation: 0,
    );
  }

  bool get _isPrimary => style == AppTopBarStyle.primary;

  Color get _bg => _isPrimary ? AppTheme.primaryColor : Colors.white;

  Color get _fg => _isPrimary ? Colors.white : AppTheme.textColor;

  Color get _iconColor =>
      _isPrimary ? Colors.white : AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _bg,
      foregroundColor: _fg,
      elevation: elevation,
      centerTitle: centerTitle,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      systemOverlayStyle: _isPrimary
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: AppTheme.primaryColor,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.white,
            ),
      title: titleWidget ?? _buildTitle(context),
      actions: _buildActions(context),
    );
  }

  Widget? _buildTitle(BuildContext context) {
    if (showUserName) {
      return _UserTitle(
        fallbackInitial: fallbackInitial,
        isPrimary: _isPrimary,
      );
    }
    if (title == null || title!.isEmpty) return null;
    return Text(
      title!,
      style: TextStyle(
        color: _fg,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final list = <Widget>[...?(actions)];

    if (showNotifications) {
      list.add(
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: _iconColor),
          tooltip: 'الإشعارات',
          onPressed: onNotificationsTap ??
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📬 سيتم فتح الإشعارات قريباً'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
        ),
      );
    }

    if (showLogout) {
      list.add(
        IconButton(
          icon: Icon(
            Icons.logout,
            color: _isPrimary ? Colors.white : Colors.red,
          ),
          tooltip: 'تسجيل الخروج',
          onPressed: () => _showLogoutDialog(context),
        ),
      );
    }

    return list;
  }

  void _showLogoutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
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
                if (onLogoutConfirmed != null) {
                  await onLogoutConfirmed!();
                } else {
                  await authProvider.signOut();
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}

class _UserTitle extends StatelessWidget {
  final String fallbackInitial;
  final bool isPrimary;

  const _UserTitle({
    required this.fallbackInitial,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = context.select<AuthProvider, String>(
      (auth) => auth.userData?.fullName.trim() ?? '',
    );

    final initial =
        cleanName.isNotEmpty ? cleanName.characters.first : fallbackInitial;

    final avatarBg = isPrimary
        ? Colors.white.withValues(alpha: 0.2)
        : AppTheme.primaryColor.withValues(alpha: 0.15);

    final avatarFg = isPrimary ? Colors.white : AppTheme.primaryColor;
    final nameColor = isPrimary ? Colors.white : Colors.black87;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: avatarBg,
          radius: 18,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: avatarFg,
            ),
          ),
        ),
        if (cleanName.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              cleanName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: nameColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
