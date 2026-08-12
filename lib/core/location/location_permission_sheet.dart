import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';

/// نتيجة اختيار المستخدم من ورقة صلاحية الموقع
enum LocationPermissionChoice {
  /// أثناء استخدام التطبيق فقط
  whileInUse,

  /// دائماً
  always,

  /// رفض
  denied,
}

/// ورقة بثلاثة خيارات:
/// - أثناء استخدام التطبيق
/// - دائماً
/// - عدم السماح
///
/// عند إيقاف GPS تظهر رسالة منفصلة لفتح إعدادات الموقع.
class LocationPermissionSheet {
  LocationPermissionSheet._();

  static Future<LocationPermissionChoice?> show(BuildContext context) {
    return showModalBottomSheet<LocationPermissionChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).padding.bottom;
        final onSurface = Theme.of(ctx).colorScheme.onSurface;

        return Container(
          margin: const EdgeInsets.all(12),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 32,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'السماح بالوصول إلى موقعك؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'نستخدم موقعك لإظهار علامتك على الخريطة وتحسين التتبع.\n'
                'يمكنك تغيير هذا لاحقاً من إعدادات الجهاز.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),
              _OptionTile(
                icon: Icons.phone_android_rounded,
                title: 'أثناء استخدام التطبيق',
                subtitle: 'مُفضّل لمعظم الاستخدامات',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.pop(
                  ctx,
                  LocationPermissionChoice.whileInUse,
                ),
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.all_inclusive_rounded,
                title: 'دائماً',
                subtitle: 'حتى في الخلفية (قد يطلب إعدادات النظام)',
                color: Colors.teal.shade700,
                onTap: () => Navigator.pop(
                  ctx,
                  LocationPermissionChoice.always,
                ),
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.block_rounded,
                title: 'عدم السماح',
                subtitle: 'لن نتمكن من تحديد موقعك على الخريطة',
                color: Colors.red.shade600,
                onTap: () => Navigator.pop(
                  ctx,
                  LocationPermissionChoice.denied,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// يعرض الورقة إن لزم، ثم يطلب صلاحية النظام ويعيد true عند المنح.
  static Future<bool> ensurePermission(
    BuildContext context, {
    bool forcePrompt = false,
  }) async {
    // ── GPS / خدمة الموقع متوقفة ───────────────────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'خدمة الموقع متوقفة',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'الجي بي إس (GPS) غير مفعّل على جهازك.\n'
              'فعّله من الإعدادات ثم أعد المحاولة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('فتح الإعدادات'),
              ),
            ],
          ),
        );
        if (open == true) await Geolocator.openLocationSettings();
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();

    final alreadyGranted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (alreadyGranted && !forcePrompt) return true;

    // ── رفض دائم: يجب التعديل من إعدادات التطبيق ───────────
    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'الصلاحية مرفوضة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'تم رفض صلاحية الموقع بشكل دائم.\n'
            'افتح إعدادات التطبيق وفعّل الموقع يدوياً.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('فتح الإعدادات'),
            ),
          ],
        ),
      );
      if (open == true) await Geolocator.openAppSettings();
      return false;
    }

    // ── ورقة الخيارات الثلاثة ───────────────────────────────
    if (!context.mounted) return false;
    final choice = await show(context);
    if (choice == null || choice == LocationPermissionChoice.denied) {
      return false;
    }

    // حوار النظام الحقيقي بعد اختيار المستخدم
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // خيار «دائماً»: غالباً يحتاج إعدادات النظام بعد While In Use
    if (choice == LocationPermissionChoice.always &&
        permission != LocationPermission.always) {
      if (context.mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'الوصول الدائم للموقع',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'تم منح الوصول أثناء استخدام التطبيق.\n\n'
              'لتفعيله «دائماً»، افتح إعدادات التطبيق واختر:\n'
              'الموقع → السماح طوال الوقت / Always.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('لاحقاً'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('فتح الإعدادات'),
              ),
            ],
          ),
        );
        if (open == true) await Geolocator.openAppSettings();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
