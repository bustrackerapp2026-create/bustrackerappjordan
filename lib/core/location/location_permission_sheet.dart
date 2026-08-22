import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;

/// 1) نافذة صلاحية النظام (تقريبي/دقيق + أثناء الاستخدام / هذه المرّة فقط)
/// 2) إذا GPS مغلق: نافذة النظام لتفعيل خدمة الموقع (وليست إعدادات كاملة أولاً)
class LocationPermissionSheet {
  LocationPermissionSheet._();

  /// صلاحية التطبيق عبر نافذة النظام — حتى لو GPS مغلق.
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
      if (alreadyGranted && !forcePrompt) {
        return true;
      }

      // نافذة أندرويد الرسمية للصلاحية (مثل صورة Vision City Bus)
      permission = await Geolocator.requestPermission();

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensurePermission: $e');
      return false;
    }
  }

  /// تفعيل GPS عبر نافذة النظام (requestService) وليس فتح الإعدادات مباشرة.
  static Future<bool> ensureLocationService(BuildContext context) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        return true;
      }

      // أندرويد: نافذة النظام الرسمية «تشغيل الموقع؟»
      if (!kIsWeb && Platform.isAndroid) {
        final location = loc.Location();
        final turnedOn = await location.requestService();
        if (turnedOn) return true;
        // إذا رفض المستخدم النافذة
        return await Geolocator.isLocationServiceEnabled();
      }

      // iOS أو غير أندرويد: لا توجد نافذة نظام مماثلة — نوجّه للإعدادات
      if (!context.mounted) return false;
      final open = await _confirmAction(
        context,
        title: 'خدمة الموقع متوقفة',
        message:
            'الموقع مغلق على الجهاز.\nفعّله من الإعدادات لإظهار موقعك على الخريطة.',
        confirmLabel: 'فتح الإعدادات',
        cancelLabel: 'لاحقاً',
      );
      if (open) await Geolocator.openLocationSettings();
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensureLocationService: $e');
      // احتياطي: فتح إعدادات الموقع
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
      return await Geolocator.isLocationServiceEnabled();
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
