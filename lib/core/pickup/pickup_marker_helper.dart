import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// رسّام علامات نقاط التجمع الموحد لكل الخرائط (أدمن / سائق / راكب).
///
/// - تجمع باصات  → برتقالي + أيقونة باص
/// - تجمع ركاب   → نيلي + أيقونة ركاب
/// بدون شارة حمراء لعدد التأكيدات.
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

  /// إنشاء صورة PNG للعلامة (بدون شارة التأكيدات الحمراء)
  static Future<Uint8List?> createMarkerBytes({
    required String name,
    required String pointType,
    int confirmationCount = 0,
  }) async {
    final safeName = name.trim().isEmpty ? 'نقطة' : name.trim();
    // لا نضمّن confirmationCount في المفتاح — الشارة لم تعد تُرسم
    final cacheKey = 'pickup_${pointType}_${safeName.hashCode}';

    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const double width = 140.0;
      const double height = 120.0;
      const Offset pinCenter = Offset(width / 2, 42);

      canvas.drawColor(Colors.transparent, BlendMode.clear);

      final Color primary = primaryColorFor(pointType);
      final Color glow = glowColorFor(pointType);

      // توهج خارجي
      final glowPaint = Paint()
        ..color = glow.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(pinCenter, 36, glowPaint);

      // حلقة بيضاء خارجية
      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pinCenter, 26, outerPaint);

      // الدائرة الداخلية الملونة
      final innerPaint = Paint()
        ..color = primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pinCenter, 20, innerPaint);

      // أيقونة
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

      // رأس الدبوس السفلي
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

      // فقاعة الاسم
      final displayName =
          safeName.length > 16 ? '${safeName.substring(0, 15)}…' : safeName;

      final namePainter = TextPainter(
        text: TextSpan(
          text: displayName,
          style: TextStyle(
            color: Colors.grey.shade900,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      );
      namePainter.layout(maxWidth: width - 20);

      final bubbleWidth = (namePainter.width + 20).clamp(48.0, width - 8);
      const bubbleHeight = 26.0;
      final bubbleLeft = (width - bubbleWidth) / 2;
      const bubbleTop = height - bubbleHeight - 4;

      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
        const Radius.circular(13),
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
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      _cache[cacheKey] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('⚠️ [PickupMarkerHelper] فشل رسم العلامة: $e');
      return null;
    }
  }

  static void clearCache() => _cache.clear();
}
