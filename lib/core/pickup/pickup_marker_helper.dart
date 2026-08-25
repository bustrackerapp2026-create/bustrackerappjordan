import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// رسّام علامات نقاط التجمع — نص عربي واضح بخط النظام.
class PickupMarkerHelper {
  PickupMarkerHelper._();

  static final Map<String, Uint8List> _cache = {};

  static Color primaryColorFor(String pointType) {
    return pointType == 'passenger'
        ? const Color(0xFF3949AB)
        : const Color(0xFF1D8FE1);
  }

  static Color glowColorFor(String pointType) {
    return pointType == 'passenger'
        ? const Color(0xFF5C6BC0)
        : const Color(0xFF42A5F5);
  }

  static IconData iconFor(String pointType) {
    return pointType == 'passenger'
        ? Icons.people_alt_rounded
        : Icons.directions_bus_rounded;
  }

  static Future<Uint8List?> createMarkerBytes({
    required String name,
    required String pointType,
    int confirmationCount = 0,
    double textScale = 1.0,
  }) async {
    final safeName = name.trim().isEmpty ? 'نقطة' : name.trim();
    final scale = textScale.clamp(0.85, 2.2);
    final scaleKey = (scale * 100).round();
    final cacheKey = 'pickup_v3_${pointType}_${safeName.hashCode}_s$scaleKey';

    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // خط أوضح: أساس 15 بدل 12
      final double width = 168.0 + (scale - 1.0) * 56;
      final double fontSize = 15.0 * scale;
      final double bubbleHeight = (32.0 * scale).clamp(32.0, 52.0);
      final double height = 128.0 + (bubbleHeight - 32.0) + (scale - 1.0) * 10;
      final Offset pinCenter = Offset(width / 2, 42);

      canvas.drawColor(Colors.transparent, BlendMode.clear);

      final Color primary = primaryColorFor(pointType);
      final Color glow = glowColorFor(pointType);

      final glowPaint = Paint()
        ..color = glow.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(pinCenter, 34, glowPaint);

      canvas.drawCircle(
        pinCenter,
        26,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        pinCenter,
        20,
        Paint()
          ..color = primary
          ..style = PaintingStyle.fill,
      );

      final iconData = iconFor(pointType);
      final iconPainter = TextPainter(textDirection: TextDirection.ltr);
      iconPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 20,
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
          pinCenter.dy - iconPainter.height / 2 - 0.5,
        ),
      );

      final tipPath = Path()
        ..moveTo(pinCenter.dx - 10, pinCenter.dy + 16)
        ..lineTo(pinCenter.dx, pinCenter.dy + 34)
        ..lineTo(pinCenter.dx + 10, pinCenter.dy + 16)
        ..close();
      canvas.drawPath(tipPath, Paint()..color = primary);
      canvas.drawPath(
        tipPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final maxChars = scale >= 1.5 ? 22 : (scale >= 1.25 ? 20 : 18);
      final displayName = safeName.length > maxChars
          ? '${safeName.substring(0, maxChars - 1)}…'
          : safeName;

      final namePainter = TextPainter(
        text: TextSpan(
          text: displayName,
          style: TextStyle(
            color: const Color(0xFF111827),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      );
      namePainter.layout(maxWidth: width - 16);

      final bubbleWidth =
          (namePainter.width + 24 * scale).clamp(56.0, width - 8);
      final bubbleLeft = (width - bubbleWidth) / 2;
      final bubbleTop = height - bubbleHeight - 4;

      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
        Radius.circular(14 * scale.clamp(1.0, 1.35)),
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
          ..color = primary.withValues(alpha: 0.30)
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
