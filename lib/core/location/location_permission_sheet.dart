import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// 1) صلاحية التطبيق (نافذة النظام)
/// 2) تفعيل GPS (نافذة Google بضغطة واحدة، ثم إعدادات كاحتياطي)
class LocationPermissionSheet {
  LocationPermissionSheet._();

  static const MethodChannel _locationChannel =
      MethodChannel('com.example.jordan_bus_tracker/location_service');

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

  static Future<bool> ensureLocationService(BuildContext context) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        return true;
      }

      if (!kIsWeb && Platform.isAndroid) {
        // نافذة النظام: تفعيل الموقع بضغطة واحدة
        try {
          final enabled =
              await _locationChannel.invokeMethod<bool>('enableLocationService');
          if (enabled == true) return true;
          if (await Geolocator.isLocationServiceEnabled()) return true;
        } catch (e) {
          debugPrint('enableLocationService channel: $e');
        }
      }

      // احتياطي: حوار ثم صفحة إعدادات الموقع
      if (!context.mounted) return false;
      final open = await _confirmAction(
        context,
        title: 'فعّل خدمة الموقع',
        message:
            'الموقع مغلق على الجهاز.\nاضغط «تفعيل» لفتح إعدادات الموقع وتشغيله، ثم ارجع للتطبيق.',
        confirmLabel: 'تفعيل',
        cancelLabel: 'لاحقاً',
      );
      if (open) {
        await Geolocator.openLocationSettings();
        // بعد العودة من الإعدادات
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
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
