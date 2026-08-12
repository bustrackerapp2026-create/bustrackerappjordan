import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// نتيجة اختيار المستخدم (للتوافق مع الاستدعاءات القديمة إن وُجدت).
enum LocationPermissionChoice {
  whileInUse,
  always,
  denied,
}

/// إدارة صلاحية الموقع بأسلوب قريب من خرائط Google:
/// حوار **النظام** الأصلي فقط (Allow / While using the app / Deny)،
/// بدون ورقة مخصّصة بثلاثة خيارات داخل التطبيق.
class LocationPermissionSheet {
  LocationPermissionSheet._();

  /// لم يعد يُعرض اختيار مخصّص — يُرجع null.
  /// أُبقي للتوافق إن وُجد استدعاء قديم لـ [show].
  @Deprecated('Use ensurePermission — system dialog only')
  static Future<LocationPermissionChoice?> show(BuildContext context) async {
    return null;
  }

  /// يفعّل خدمة الموقع إن لزم، ثم يطلب صلاحية **النظام** مباشرة.
  static Future<bool> ensurePermission(
    BuildContext context, {
    bool forcePrompt = false,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        final open = await _showSimpleDialog(
          context,
          title: 'خدمة الموقع متوقفة',
          message:
              'فعّل GPS / خدمة الموقع من إعدادات الجهاز حتى نتمكن من تحديد موقعك على الخريطة.',
          confirmLabel: 'فتح الإعدادات',
        );
        if (open == true) await Geolocator.openLocationSettings();
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();

    final alreadyGranted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (alreadyGranted && !forcePrompt) return true;

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final open = await _showSimpleDialog(
        context,
        title: 'صلاحية الموقع مطلوبة',
        message:
            'تم إيقاف صلاحية الموقع لهذا التطبيق. افتح الإعدادات وفعّل الموقع يدوياً.',
        confirmLabel: 'فتح الإعدادات',
      );
      if (open == true) await Geolocator.openAppSettings();
      return false;
    }

    // مثل Google Maps: حوار النظام فقط (بدون ورقة خيارات داخل التطبيق)
    permission = await Geolocator.requestPermission();

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<bool?> _showSimpleDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
