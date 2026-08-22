import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// يطلب صلاحية الموقع عبر نافذة النظام الرسمية (أندرويد/iOS)
/// مثل: أثناء استخدام التطبيق / هذه المرّة فقط / عدم السماح
/// مع خيار تقريبي / دقيق على أندرويد 12+.
class LocationPermissionSheet {
  LocationPermissionSheet._();

  /// يعيد true فقط إذا:
  /// 1) صلاحية التطبيق ممنوحة (whileInUse أو always)
  /// 2) خدمة الموقع (GPS) مفعّلة على الجهاز
  static Future<bool> ensurePermission(
    BuildContext context, {
    bool forcePrompt = false,
  }) async {
    try {
      var permission = await Geolocator.checkPermission();

      // رفض دائم → لا تظهر نافذة النظام؛ يجب التعديل من إعدادات التطبيق
      if (permission == LocationPermission.deniedForever) {
        if (!context.mounted) return false;
        final open = await _confirmAction(
          context,
          title: 'صلاحية الموقع مرفوضة',
          message:
              'تم رفض صلاحية الموقع بشكل دائم.\nافتح إعدادات التطبيق وفعّل الموقع يدوياً.',
          confirmLabel: 'فتح الإعدادات',
          cancelLabel: 'لاحقاً',
        );
        if (open) await Geolocator.openAppSettings();
        return false;
      }

      final alreadyGranted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      // طلب صلاحية النظام إذا لم تُمنح بعد (أو عند forcePrompt)
      if (!alreadyGranted || forcePrompt) {
        // ── نافذة النظام الرسمية ──
        // أندرويد: تقريبي/دقيق + أثناء الاستخدام / هذه المرّة فقط / عدم السماح
        permission = await Geolocator.requestPermission();
      }

      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (!granted) return false;

      // دائماً نتحقق من خدمة الموقع — حتى لو كانت الصلاحية ممنوحة مسبقاً
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!context.mounted) return false;
        final open = await _confirmAction(
          context,
          title: 'خدمة الموقع متوقفة',
          message:
              'الموقع (GPS) غير مفعّل على جهازك.\nفعّله من الإعدادات ثم أعد المحاولة لإظهار موقعك على الخريطة.',
          confirmLabel: 'فتح الإعدادات',
          cancelLabel: 'لاحقاً',
        );
        if (open) await Geolocator.openLocationSettings();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensurePermission: $e');
      return false;
    }
  }

  static Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'إلغاء',
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }
}
