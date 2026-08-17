import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// علامات بداية/نهاية خفيفة:
/// - البداية: دائرة ممتلئة + نقطة بيضاء
/// - النهاية: دائرة مفرّغة (outline)
/// بدون نص على الخريطة — اللون يتبع اتجاه الخط.
class RouteEndpointMarkers {
  RouteEndpointMarkers._();

  static final Map<String, Uint8List> _cache = {};

  /// بداية المسار — دائرة ممتلئة
  static Future<Uint8List> start({Color color = const Color(0xFF1D8FE1)}) {
    return _build(
      key: 'start_v2_${color.toARGB32()}',
      color: color,
      isStart: true,
    );
  }

  /// نهاية المسار — دائرة مفرّغة بنفس لون الاتجاه
  static Future<Uint8List> end({Color color = const Color(0xFF1D8FE1)}) {
    return _build(
      key: 'end_v2_${color.toARGB32()}',
      color: color,
      isStart: false,
    );
  }

  static Future<Uint8List> _build({
    required String key,
    required Color color,
    required bool isStart,
  }) async {
    final cached = _cache[key];
    if (cached != null) return cached;

    // صورة مربعة صغيرة — خفيفة على الخريطة
    const double size = 64;
    final center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ظل خفيف جداً
    canvas.drawCircle(
      center.translate(0, 1.2),
      18,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    if (isStart) {
      // حلقة بيضاء خارجية
      canvas.drawCircle(
        center,
        17.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      // دائرة اللون ممتلئة
      canvas.drawCircle(
        center,
        14.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      // نقطة بيضاء في الوسط
      canvas.drawCircle(
        center,
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    } else {
      // نهاية: قرص أبيض ثم حلقة لون سميكة (مفرّغة)
      canvas.drawCircle(
        center,
        17.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        14.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5,
      );
      // مركز شفاف يظهر كـ outline واضح
      canvas.drawCircle(
        center,
        8.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = bytes!.buffer.asUint8List();
    _cache[key] = out;
    return out;
  }
}
