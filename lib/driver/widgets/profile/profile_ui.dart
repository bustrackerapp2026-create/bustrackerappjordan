import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// عناصر واجهة مشتركة لتبويب الملف الشخصي للسائق.
class ProfileUi {
  ProfileUi._();

  static Color _surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color _onSurface(BuildContext context, {double alpha = 1}) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha);

  static Widget avatar({
    String? photoUrl,
    required String initial,
    double size = 64,
  }) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto
            ? null
            : LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.75),
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  static Widget avatarWithCamera({
    required String? photoUrl,
    required String initial,
    required VoidCallback onTap,
    double size = 64,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          avatar(photoUrl: photoUrl, initial: initial, size: size),
          Container(
            padding: EdgeInsets.all(size > 70 ? 6 : 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.camera_alt,
              size: size > 70 ? 16 : 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Widget chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Widget infoRow(IconData icon, String label, String value) {
    return Builder(
      builder: (context) {
        return Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _onSurface(context, alpha: 0.55),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _onSurface(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget sectionTitle(String text) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _onSurface(context, alpha: 0.65),
            ),
          ),
        );
      },
    );
  }

  static Widget sectionCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  static Widget tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        return ListTile(
          leading: Icon(icon, color: AppTheme.primaryColor),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _onSurface(context),
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(color: _onSurface(context, alpha: 0.6)),
                )
              : null,
          trailing: Icon(
            Icons.chevron_left,
            color: _onSurface(context, alpha: 0.35),
          ),
          onTap: onTap,
        );
      },
    );
  }

  static Widget divider() {
    return Builder(
      builder: (context) {
        return Divider(
          height: 1,
          color: Theme.of(context).dividerColor,
        );
      },
    );
  }
}
