import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// يطلب صلاحية الموقع عبر نافذة النظام الرسمية أولاً
/// (تقريبي / دقيق + أثناء الاستخدام / هذه المرّة فقط / عدم السماح)
/// حتى لو كانت خدمة الموقع (GPS) متوقفة على الجهاز.
class LocationPermissionSheet {
  LocationPermissionSheet._();

  /// يعيد true إذا مُنحت صلاحية التطبيق (whileInUse أو always).
  /// لا يفحص GPS قبل نافذة النظام — الفحص يكون لاحقاً عند جلب الموقع.
  static Future<bool> ensurePermission(
    BuildContext context, {
    bool forcePrompt = false,
  }) async {
    try {
      var permission = await Geolocator.checkPermission();

      // رفض دائم فقط: لا يمكن إظهار نافذة النظام
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

      // إذا ممنوحة مسبقاً ولا نريد إعادة الطلب — نجح
      final alreadyGranted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (alreadyGranted && !forcePrompt) {
        return true;
      }

      // ── دائماً نطلب صلاحية النظام هنا (حتى لو GPS مغلق) ──
      // هذه هي نافذة أندرويد الرسمية مثل صورة Vision City Bus
      permission = await Geolocator.requestPermission();

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensurePermission: $e');
      return false;
    }
  }

  /// بعد منح الصلاحية: إذا كان GPS متوقفاً نعرض حوار فتح الإعدادات.
  static Future<bool> ensureLocationService(BuildContext context) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) return true;

      if (!context.mounted) return false;
      final open = await _confirmAction(
        context,
        title: 'خدمة الموقع متوقفة',
        message:
            'تم السماح للتطبيق، لكن الموقع (GPS) مغلق على الجهاز.\nفعّله لإظهار موقعك على الخريطة.',
        confirmLabel: 'فتح الإعدادات',
        cancelLabel: 'لاحقاً',
      );
      if (open) await Geolocator.openLocationSettings();
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensureLocationService: $e');
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
