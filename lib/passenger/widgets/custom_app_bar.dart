import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

/// شريط علوي مخصّص لشاشة الراكب فقط — مظهر أوضح من AppBar العادي.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  static const double _barHeight = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final cleanName = context.select<AuthProvider, String>(
      (auth) => auth.userData?.fullName.trim() ?? '',
    );
    final initial = cleanName.isNotEmpty ? cleanName.characters.first : 'ر';

    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final nameColor = isDark ? AppTheme.darkText : AppTheme.textColor;
    final mutedColor =
        isDark ? AppTheme.darkTextSecondary : const Color(0xFF5F6368);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: surface,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: surface,
            ),
      child: Material(
        color: surface,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _barHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    // Avatar + greeting
                    _AvatarBadge(initial: initial, isDark: isDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greetingLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cleanName.isNotEmpty ? cleanName : 'راكب',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: nameColor,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.notifications_outlined,
                      tooltip: l10n.notifications,
                      color: AppTheme.primaryColor,
                      isDark: isDark,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.notificationsComingSoon),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    _RoundIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: l10n.logout,
                      color: const Color(0xFFDC2626),
                      isDark: isDark,
                      onPressed: () => _showLogoutDialog(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _greetingLabel() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء النور';
    return 'مساء الخير';
  }

  void _showLogoutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                await authProvider.signOut();
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
}

class _AvatarBadge extends StatelessWidget {
  final String initial;
  final bool isDark;

  const _AvatarBadge({
    required this.initial,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A73E8),
            Color(0xFF0B57D0),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          width: 2.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool isDark;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}
