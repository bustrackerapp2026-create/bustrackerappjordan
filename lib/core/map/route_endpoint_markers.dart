import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// علامات بداية/نهاية خفيفة مع هالة توهج:
/// - البداية: دائرة ممتلئة + نقطة بيضاء
/// - النهاية: دائرة مفرّغة (outline)
/// النبض اللوني يُطبَّق من الخريطة عبر تغيير الحجم/الشفافية.
class RouteEndpointMarkers {
  RouteEndpointMarkers._();

  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List> start({Color color = const Color(0xFF1D8FE1)}) {
    return _build(
      key: 'start_v3_${color.toARGB32()}',
      color: color,
      isStart: true,
    );
  }

  static Future<Uint8List> end({Color color = const Color(0xFF1D8FE1)}) {
    return _build(
      key: 'end_v3_${color.toARGB32()}',
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

    // مساحة أكبر للهالة المتوهجة حول الدائرة
    const double size = 96;
    final center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // هالة توهج خارجية (ناعمة)
    canvas.drawCircle(
      center,
      36,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      28,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ظل خفيف للعمق
    canvas.drawCircle(
      center.translate(0, 1.5),
      18,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    if (isStart) {
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
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    } else {
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
