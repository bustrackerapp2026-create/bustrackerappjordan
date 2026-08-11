import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

/// نمط مظهر الشريط العلوي
enum AppTopBarStyle {
  /// خلفية بيضاء ونص داكن (راكب / سائق)
  light,

  /// خلفية اللون الأساسي ونص أبيض (أدمن / شاشات النظام)
  primary,
}

/// الشريط العلوي الموحّد للتطبيق — يُستخدم في كل الشاشات.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showUserName;
  final String fallbackInitial;
  final bool showNotifications;
  final bool showLogout;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool centerTitle;
  final AppTopBarStyle style;
  final double height;
  final double elevation;
  final VoidCallback? onNotificationsTap;
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
    final l10n = AppLocalizations.of(context);
    final list = <Widget>[...?(actions)];

    if (showNotifications) {
      list.add(
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: _iconColor),
          tooltip: l10n.notifications,
          onPressed: onNotificationsTap ??
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.notificationsComingSoon),
                    duration: const Duration(seconds: 2),
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
          tooltip: l10n.logout,
          onPressed: () => _showLogoutDialog(context),
        ),
      );
    }

    return list;
  }

  void _showLogoutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.logout,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
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
                    content: Text('$e'),
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
            child: Text(l10n.confirmLogout),
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
