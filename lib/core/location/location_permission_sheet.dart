import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;

/// تدفق الموقع:
/// 1) نافذة صلاحية التطبيق الرسمية (تقريبي/دقيق — أثناء الاستخدام / هذه المرّة فقط)
/// 2) إذا GPS مغلق: نافذة النظام لتفعيل الموقع بضغطة واحدة (بدون فتح الإعدادات يدوياً)
class LocationPermissionSheet {
  LocationPermissionSheet._();

  static const MethodChannel _locationChannel =
      MethodChannel('com.example.jordan_bus_tracker/location_service');

  /// صلاحية التطبيق — نافذة أندرويد الرسمية.
  static Future<bool> ensurePermission(
    BuildContext context, {
    bool forcePrompt = false,
  }) async {
    try {
      var permission = await Geolocator.checkPermission();

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

      // أظهر نافذة النظام إذا لم تُمنح بعد، أو عند forcePrompt
      if (!alreadyGranted || forcePrompt) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensurePermission: $e');
      return false;
    }
  }

  /// تفعيل GPS عبر نافذة النظام بضغطة واحدة (LocationSettings dialog).
  static Future<bool> ensureLocationService(BuildContext context) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        return true;
      }

      if (!kIsWeb && Platform.isAndroid) {
        // 1) نافذة Google Play Services الرسمية — تفعّل الموقع مباشرة عند الموافقة
        try {
          final enabled =
              await _locationChannel.invokeMethod<bool>('enableLocationService');
          if (enabled == true) {
            return true;
          }
        } catch (e) {
          debugPrint('enableLocationService channel: $e');
        }

        // 2) احتياطي: حزمة location
        try {
          final turnedOn = await loc.Location().requestService();
          if (turnedOn) return true;
        } catch (e) {
          debugPrint('location.requestService: $e');
        }

        return await Geolocator.isLocationServiceEnabled();
      }

      // iOS: لا توجد نافذة تفعيل GPS برمجياً
      if (!context.mounted) return false;
      final open = await _confirmAction(
        context,
        title: 'خدمة الموقع متوقفة',
        message: 'فعّل الموقع من إعدادات الجهاز ثم أعد المحاولة.',
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
