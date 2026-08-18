import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';

/// أيقونات معالم المشروع — تُولَّد مرة وتُخزَّن في الذاكرة.
/// أسلوب قريب من POI Mapbox (دائرة ملونة + رمز أبيض) بحجم موحّد للخريطة.
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  static const double markerSize = 88;

  static final Map<MapLandmarkType, Uint8List> _cache = {};

  /// لون النوع (متوافق مع ألوان بطاقة POI الحالية قدر الإمكان).
  static Color colorFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.mosque:
        return const Color(0xFF00897B);
      case MapLandmarkType.restaurant:
        return const Color(0xFFFB8C00);
      case MapLandmarkType.university:
        return const Color(0xFF5E35B1);
      case MapLandmarkType.hospital:
        return const Color(0xFFE53935);
      case MapLandmarkType.school:
        return const Color(0xFF1E88E5);
      case MapLandmarkType.shop:
        return const Color(0xFF8E24AA);
      case MapLandmarkType.park:
        return const Color(0xFF2E7D32);
      case MapLandmarkType.government:
        return const Color(0xFF546E7A);
      case MapLandmarkType.other:
        return const Color(0xFF607D8B);
    }
  }

  /// أيقونة Material مقابلة للنوع (للواجهات والقائمة).
  static IconData iconDataFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.mosque:
        return Icons.mosque_rounded;
      case MapLandmarkType.restaurant:
        return Icons.restaurant_rounded;
      case MapLandmarkType.university:
        return Icons.account_balance_rounded;
      case MapLandmarkType.hospital:
        return Icons.local_hospital_rounded;
      case MapLandmarkType.school:
        return Icons.school_rounded;
      case MapLandmarkType.shop:
        return Icons.storefront_rounded;
      case MapLandmarkType.park:
        return Icons.park_rounded;
      case MapLandmarkType.government:
        return Icons.account_balance_outlined;
      case MapLandmarkType.other:
        return Icons.place_rounded;
    }
  }

  /// PNG جاهز لـ Mapbox PointAnnotation (مع تخزين مؤقت).
  static Future<Uint8List> bytesFor(MapLandmarkType type) async {
    final hit = _cache[type];
    if (hit != null) return hit;
    final bytes = await _render(type);
    _cache[type] = bytes;
    return bytes;
  }

  /// تحميل مسبق لكل الأنواع (اختياري عند فتح الخريطة).
  static Future<void> preloadAll() async {
    for (final t in MapLandmarkType.values) {
      await bytesFor(t);
    }
  }

  static void clearCache() => _cache.clear();

  static Future<Uint8List> _render(MapLandmarkType type) async {
    const size = markerSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = colorFor(type);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 1.5), 28, shadow);

    final outer = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 28, outer);

    final fill = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), 23, fill);

    final icon = iconDataFor(type);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2 - 1),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }
}
