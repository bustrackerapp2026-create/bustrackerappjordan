import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_theme.dart';
import 'map_constants.dart';

/// دوال مساعدة مشتركة للخرائط
class MapUtils {
  // ─── Logger ──────────────────────────────────────────────────────
  /// تسجيل الرسائل في وضع التطوير فقط
  static void log(String message, {String tag = 'Map'}) {
    if (kDebugMode) {
      debugPrint('📌 [$tag] $message');
    }
  }

  // ─── SnackBar ──────────────────────────────────────────────────
  /// عرض رسالة منبثقة (SnackBar) موحدة
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ??
            (isError ? Colors.red.shade700 : AppTheme.primaryColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
      ),
    );
  }

  // ─── تحويل اللون من Hex ──────────────────────────────────────
  /// تحويل لون من صيغة Hex (مثل #2196F3) إلى Color
  static Color hexToColor(String hex) {
    try {
      final hexCode = hex.replaceAll('#', '');
      if (hexCode.length == 6) {
        return Color(int.parse('FF$hexCode', radix: 16));
      }
      if (hexCode.length == 8) {
        return Color(int.parse(hexCode, radix: 16));
      }
    } catch (e) {
      log('⚠️ خطأ في تحويل اللون الهكس: $e');
    }
    return Colors.blue;
  }

  // ─── التحقق من صحة الإحداثيات ──────────────────────────────────
  /// التحقق من أن خط العرض ضمن النطاق الصحيح
  static bool isValidLatitude(double lat) {
    return lat >= -90.0 && lat <= 90.0;
  }

  /// التحقق من أن خط الطول ضمن النطاق الصحيح
  static bool isValidLongitude(double lng) {
    return lng >= -180.0 && lng <= 180.0;
  }

  /// التحقق من أن الإحداثيات ضمن حدود الأردن
  static bool isWithinJordanBounds(double lat, double lng) {
    return lat >= MapConstants.minLat &&
        lat <= MapConstants.maxLat &&
        lng >= MapConstants.minLng &&
        lng <= MapConstants.maxLng;
  }

  // ─── تحويل آمن من Firestore إلى double ──────────────────────────
  /// تحويل قيمة من Firestore إلى double بأمان
  /// تدعم: num, int, String, double, null
  static double? safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    if (value is num) return value.toDouble();
    return null;
  }
}
