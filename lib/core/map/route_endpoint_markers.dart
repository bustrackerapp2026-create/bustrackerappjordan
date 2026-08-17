import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// مولّد علامات بداية/نهاية المسار (صور PNG للاستخدام مع PointAnnotation).
class RouteEndpointMarkers {
  RouteEndpointMarkers._();

  static final Map<String, Uint8List> _cache = {};

  /// بداية المسار — دائرة مع نقطة داخلية ونص «بداية»
  static Future<Uint8List> start({Color color = const Color(0xFF1D8FE1)}) {
    return _build(
      key: 'start_${color.toARGB32()}',
      color: color,
      label: 'بداية',
      isStart: true,
    );
  }

  /// نهاية المسار — دائرة مع مربع صغير ونص «نهاية»
  static Future<Uint8List> end({Color color = const Color(0xFFE11D48)}) {
    return _build(
      key: 'end_${color.toARGB32()}',
      color: color,
      label: 'نهاية',
      isStart: false,
    );
  }

  static Future<Uint8List> _build({
    required String key,
    required Color color,
    required String label,
    required bool isStart,
  }) async {
    final cached = _cache[key];
    if (cached != null) return cached;

    const double w = 120;
    const double h = 140;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ظل
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(w / 2, 52), 28, shadow);

    // دائرة خارجية بيضاء
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(w / 2, 50), 26, ring);

    // دائرة اللون
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(w / 2, 50), 21, fill);

    // رمز داخلي
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    if (isStart) {
      // مثلث اتجاه / نقطة انطلاق
      final path = Path()
        ..moveTo(w / 2, 38)
        ..lineTo(w / 2 - 10, 58)
        ..lineTo(w / 2 + 10, 58)
        ..close();
      canvas.drawPath(path, white);
    } else {
      // مربع نهاية
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(w / 2 - 8, 42, 16, 16),
          const Radius.circular(3),
        ),
        white,
      );
    }

    // ساق الدبوس
    final stem = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(w / 2, 76), const Offset(w / 2, 96), stem);
    canvas.drawCircle(const Offset(w / 2, 100), 4, fill);

    // شارة النص تحت الدبوس
    final badgeRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 108, w - 36, 26),
      const Radius.circular(13),
    );
    canvas.drawRRect(badgeRect, fill);
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: w - 40));
    canvas.drawParagraph(paragraph, const Offset(20, 112));

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = bytes!.buffer.asUint8List();
    _cache[key] = out;
    return out;
  }
}
