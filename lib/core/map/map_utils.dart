import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../map/utils/map_helpers.dart';
import 'map_constants.dart';

/// دوال مساعدة مشتركة للخرائط
class MapUtils {
  static void log(String message, {String tag = 'Map'}) {
    if (kDebugMode) {
      debugPrint('📌 [$tag] $message');
    }
  }

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

  static bool isValidLatitude(double lat) {
    return lat >= -90.0 && lat <= 90.0;
  }

  static bool isValidLongitude(double lng) {
    return lng >= -180.0 && lng <= 180.0;
  }

  static bool isWithinJordanBounds(double lat, double lng) {
    return lat >= MapConstants.minLat &&
        lat <= MapConstants.maxLat &&
        lng >= MapConstants.minLng &&
        lng <= MapConstants.maxLng;
  }

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

  static Future<Uint8List?> preloadMarkerImage() async {
    try {
      return await MapHelpers.createUserMarkerBytes();
    } catch (e) {
      log('⚠️ خطأ في تحميل صورة الماركر: $e', tag: 'MapUtils');
      return null;
    }
  }

  static Future<void> searchPlace(
    BuildContext context,
    MapboxMap? mapboxMap,
    String query,
    double currentBearing,
    LocationService locationService,
  ) async {
    if (query.trim().isEmpty) return;
    if (!context.mounted) return;

    final result = await locationService.searchPlace(query);
    if (!context.mounted) return;

    if (result == null) {
      showSnackBar(context, '⚠️ لم يتم العثور على المكان.', isError: true);
      return;
    }

    // pitch 0 أخف على الرسم من 45
    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(result.longitude, result.latitude),
        ),
        zoom: 15.0,
        bearing: currentBearing,
        pitch: 0.0,
      ),
    );
    showSnackBar(context, '🔎 تم الانتقال إلى ${result.name}', isError: false);
  }
}
