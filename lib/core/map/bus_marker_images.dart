import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/bus_capacity.dart';

/// أيقونات باص حسب السعة — مع نسخة باهتة للموقع القديم.
class BusMarkerImages {
  BusMarkerImages._();

  static final Map<String, Uint8List> _cache = {};
  static Uint8List? _defaultBytes;

  static Future<Uint8List> forCapacity(int? capacity, {bool stale = false}) async {
    final keyCap = BusCapacity.normalize(capacity) ?? -1;
    if (keyCap == -1) return defaultMarker(stale: stale);
    final cacheKey = '${keyCap}_${stale ? 's' : 'f'}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final bytes = await _draw(keyCap, stale: stale);
    _cache[cacheKey] = bytes;
    return bytes;
  }

  static Future<Uint8List> defaultMarker({bool stale = false}) async {
    if (!stale && _defaultBytes != null) return _defaultBytes!;
    final bytes = await _draw(BusCapacity.medium, stale: stale);
    if (!stale) _defaultBytes = bytes;
    return bytes;
  }

  static Future<Uint8List> _draw(int capacity, {required bool stale}) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (stale) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: stale ? 0.12 : 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 4), 18, shadow);

    switch (capacity) {
      case BusCapacity.service:
        _drawService(canvas, size, stale: stale);
        break;
      case BusCapacity.large:
        _drawLargeBus(canvas, size, stale: stale);
        break;
      case BusCapacity.medium:
      default:
        _drawMediumBus(canvas, size, stale: stale);
        break;
    }

    if (stale) {
      // نقطة برتقالية صغيرة = موقع قديم
      final warn = Paint()..color = const Color(0xFFEA580C);
      canvas.drawCircle(const Offset(size - 18, 18), 7, warn);
      final border = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(const Offset(size - 18, 18), 7, border);
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  static Color _bodyColor(Color vivid, {required bool stale}) {
    if (!stale) return vivid;
    return Color.lerp(vivid, Colors.grey.shade500, 0.55)!;
  }

  static void _drawService(Canvas canvas, double size, {required bool stale}) {
    final cx = size / 2;
    final cy = size / 2;

    final body = Paint()..color = _bodyColor(const Color(0xFFFFA000), stale: stale);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 34, height: 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(rrect, body);

    final roof = Paint()..color = _bodyColor(const Color(0xFFF57C00), stale: stale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 8), width: 30, height: 10),
        const Radius.circular(4),
      ),
      roof,
    );

    final window = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 7, cy - 2), width: 10, height: 9),
        const Radius.circular(2),
      ),
      window,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 7, cy - 2), width: 10, height: 9),
        const Radius.circular(2),
      ),
      window,
    );

    final wheel = Paint()..color = Colors.black87;
    canvas.drawCircle(Offset(cx - 10, cy + 12), 4.2, wheel);
    canvas.drawCircle(Offset(cx + 10, cy + 12), 4.2, wheel);

    final badge = Paint()..color = _bodyColor(const Color(0xFFE65100), stale: stale);
    canvas.drawCircle(Offset(cx, cy + 6), 5.5, badge);
  }

  static void _drawMediumBus(Canvas canvas, double size, {required bool stale}) {
    final cx = size / 2;
    final cy = size / 2;

    final body = Paint()..color = _bodyColor(const Color(0xFF1565C0), stale: stale);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 40),
      const Radius.circular(7),
    );
    canvas.drawRRect(rrect, body);

    final window = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 10), width: 20, height: 9),
        const Radius.circular(2),
      ),
      window,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 2), width: 20, height: 9),
        const Radius.circular(2),
      ),
      window,
    );

    final wheel = Paint()..color = Colors.black87;
    canvas.drawCircle(Offset(cx - 9, cy + 16), 3.8, wheel);
    canvas.drawCircle(Offset(cx + 9, cy + 16), 3.8, wheel);
  }

  static void _drawLargeBus(Canvas canvas, double size, {required bool stale}) {
    final cx = size / 2;
    final cy = size / 2;

    final body = Paint()..color = _bodyColor(const Color(0xFF2E7D32), stale: stale);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 36, height: 48),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, body);

    final stripe = Paint()..color = _bodyColor(const Color(0xFF1B5E20), stale: stale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 18), width: 32, height: 8),
        const Radius.circular(3),
      ),
      stripe,
    );

    final window = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (final dy in [-8.0, 2.0, 12.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy + dy), width: 24, height: 7),
          const Radius.circular(1.5),
        ),
        window,
      );
    }

    final wheel = Paint()..color = Colors.black87;
    canvas.drawCircle(Offset(cx - 11, cy + 20), 4.2, wheel);
    canvas.drawCircle(Offset(cx + 11, cy + 20), 4.2, wheel);
  }
}
