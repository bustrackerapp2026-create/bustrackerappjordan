import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// 1) صلاحية التطبيق (نافذة النظام)
/// 2) تفعيل GPS (نافذة Google مرة واحدة — بدون حوار تطبيق مكرر بعدها)
/// 3) للسائق: صلاحية «دائماً» للعمل في الخلفية أثناء القيادة
class LocationPermissionSheet {
  LocationPermissionSheet._();

  static const MethodChannel _locationChannel =
      MethodChannel('com.example.jordan_bus_tracker/location_service');

  static const int _servicePollAttempts = 10;
  static const Duration _servicePollInterval = Duration(milliseconds: 400);

  static Future<bool>? _servicePromptInFlight;

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

  /// للسائق: موقع أثناء الاستخدام ثم «السماح طوال الوقت» إن أمكن.
  ///
  /// يعيد true إذا وُجدت أي صلاحية موقع كافية للبدء.
  /// يفضّل always للخلفية؛ إن رُفضت يُسمح بالمتابعة مع whileInUse (أضعف).
  static Future<bool> ensureDriverBackgroundAccess(BuildContext context) async {
    try {
      if (!await ensurePermission(context)) return false;
      if (!context.mounted) return false;

      if (!await ensureLocationService(context)) return false;
      if (!context.mounted) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always) return true;

      // شرح قبل طلب «دائماً» (مطلوب على أندرويد 10+)
      if (permission == LocationPermission.whileInUse) {
        final accept = await _confirmAction(
          context,
          title: 'الموقع أثناء القيادة',
          message:
              'ليستمر ظهورك للركاب وأنت تقود والتطبيق في الخلفية، '
              'اختر «السماح طوال الوقت» أو «Allow all the time» في الشاشة التالية.\n\n'
              'يمكنك الرفض والمتابعة، لكن التتبع قد يتوقف عند إغلاق الشاشة.',
          confirmLabel: 'متابعة',
          cancelLabel: 'لاحقاً',
        );
        if (!context.mounted) return permission == LocationPermission.whileInUse;

        if (accept) {
          permission = await Geolocator.requestPermission();
          // بعض الأجهزة تفتح الإعدادات بدل نافذة ثانية
          if (permission != LocationPermission.always &&
              permission == LocationPermission.whileInUse) {
            final openSettings = await _confirmAction(
              context,
              title: 'تفعيل الموقع في الخلفية',
              message:
                  'من إعدادات التطبيق → الأذونات → الموقع → «السماح طوال الوقت».',
              confirmLabel: 'فتح الإعدادات',
              cancelLabel: 'لاحقاً',
            );
            if (openSettings) await Geolocator.openAppSettings();
          }
        }
      }

      permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('ensureDriverBackgroundAccess: $e');
      return false;
    }
  }

  static Future<bool> ensureLocationService(BuildContext context) async {
    final existing = _servicePromptInFlight;
    if (existing != null) {
      return existing;
    }

    final future = _ensureLocationServiceImpl(context);
    _servicePromptInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_servicePromptInFlight, future)) {
        _servicePromptInFlight = null;
      }
    }
  }

  static Future<bool> _ensureLocationServiceImpl(BuildContext context) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        return true;
      }

      if (!kIsWeb && Platform.isAndroid) {
        try {
          final enabled = await _locationChannel
              .invokeMethod<bool>('enableLocationService');
          if (enabled == true) return true;
          if (await Geolocator.isLocationServiceEnabled()) return true;

          debugPrint(
            'LocationPermissionSheet: system GPS dialog dismissed; '
            'skipping secondary app dialog',
          );
          return false;
        } catch (e) {
          debugPrint('enableLocationService channel: $e');
        }
      }

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
        final enabled = await _waitForLocationServiceEnabled();
        if (enabled) return true;
      }
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationPermissionSheet.ensureLocationService: $e');
      return false;
    }
  }

  static Future<bool> _waitForLocationServiceEnabled() async {
    for (var i = 0; i < _servicePollAttempts; i++) {
      if (await Geolocator.isLocationServiceEnabled()) {
        return true;
      }
      await Future<void>.delayed(_servicePollInterval);
    }
    return Geolocator.isLocationServiceEnabled();
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
