import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// رسّام علامات نقاط التجمع الموحد لكل الخرائط (أدمن / سائق / راكب).
class PickupMarkerHelper {
  PickupMarkerHelper._();

  static final Map<String, Uint8List> _cache = {};

  static Color primaryColorFor(String pointType) {
    return pointType == 'passenger'
        ? Colors.indigo.shade700
        : Colors.orange.shade600;
  }

  static Color glowColorFor(String pointType) {
    return pointType == 'passenger'
        ? Colors.indigo.shade600
        : Colors.orange.shade600;
  }

  static IconData iconFor(String pointType) {
    return pointType == 'passenger'
        ? Icons.people_alt_rounded
        : Icons.directions_bus_rounded;
  }

  /// إنشاء صورة PNG للعلامة.
  /// [textScale] يكبّر نص الاسم وفقاعة التسمية (1.0 عادي).
  static Future<Uint8List?> createMarkerBytes({
    required String name,
    required String pointType,
    int confirmationCount = 0,
    double textScale = 1.0,
  }) async {
    final safeName = name.trim().isEmpty ? 'نقطة' : name.trim();
    final scale = textScale.clamp(0.85, 2.2);
    final scaleKey = (scale * 100).round();
    final cacheKey = 'pickup_${pointType}_${safeName.hashCode}_s$scaleKey';

    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final double width = 140.0 + (scale - 1.0) * 48;
      final double fontSize = 12.0 * scale;
      final double bubbleHeight = (26.0 * scale).clamp(26.0, 44.0);
      final double height = 120.0 + (bubbleHeight - 26.0) + (scale - 1.0) * 8;
      const Offset pinCenterBase = Offset(70, 42);
      final Offset pinCenter = Offset(width / 2, pinCenterBase.dy);

      canvas.drawColor(Colors.transparent, BlendMode.clear);

      final Color primary = primaryColorFor(pointType);
      final Color glow = glowColorFor(pointType);

      final glowPaint = Paint()
        ..color = glow.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pinCenter, 36, glowPaint);

      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pinCenter, 26, outerPaint);

      final innerPaint = Paint()
        ..color = primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pinCenter, 20, innerPaint);

      final iconData = iconFor(pointType);
      final iconPainter = TextPainter(textDirection: TextDirection.ltr);
      iconPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 22,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: Colors.white,
        ),
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          pinCenter.dx - iconPainter.width / 2,
          pinCenter.dy - iconPainter.height / 2 - 1,
        ),
      );

      final tipPath = Path()
        ..moveTo(pinCenter.dx - 10, pinCenter.dy + 16)
        ..lineTo(pinCenter.dx, pinCenter.dy + 34)
        ..lineTo(pinCenter.dx + 10, pinCenter.dy + 16)
        ..close();
      canvas.drawPath(tipPath, innerPaint);
      canvas.drawPath(
        tipPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final maxChars = scale >= 1.5 ? 20 : (scale >= 1.25 ? 18 : 16);
      final displayName = safeName.length > maxChars
          ? '${safeName.substring(0, maxChars - 1)}…'
          : safeName;

      final namePainter = TextPainter(
        text: TextSpan(
          text: displayName,
          style: TextStyle(
            color: Colors.grey.shade900,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      );
      namePainter.layout(maxWidth: width - 16);

      final bubbleWidth =
          (namePainter.width + 20 * scale).clamp(48.0, width - 8);
      final bubbleLeft = (width - bubbleWidth) / 2;
      final bubbleTop = height - bubbleHeight - 4;

      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
        Radius.circular(13 * scale.clamp(1.0, 1.4)),
      );

      canvas.drawRRect(
        bubbleRect.shift(const Offset(0, 1.5)),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );

      canvas.drawRRect(
        bubbleRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        bubbleRect,
        Paint()
          ..color = primary.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      namePainter.paint(
        canvas,
        Offset(
          (width - namePainter.width) / 2,
          bubbleTop + (bubbleHeight - namePainter.height) / 2,
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.ceil(), height.ceil());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      if (_cache.length > 100) _cache.clear();
      _cache[cacheKey] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('⚠️ [PickupMarkerHelper] فشل رسم العلامة: $e');
      return null;
    }
  }

  static void clearCache() => _cache.clear();
}
