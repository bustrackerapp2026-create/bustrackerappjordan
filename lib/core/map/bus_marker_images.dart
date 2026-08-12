import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/bus_capacity.dart';

/// يولد أيقونات باص مميزة حسب السعة (سرفيس / متوسط / كبير) للخريطة.
///
/// الأيقونات مرسومة بـ Canvas حتى لا تعتمد على ملفات PNG خارجية.
/// يمكن لاحقاً استبدالها بصور من assets إن رغبت.
class BusMarkerImages {
  BusMarkerImages._();

  static final Map<int, Uint8List> _cache = {};
  static Uint8List? _defaultBytes;

  static Future<Uint8List> forCapacity(int? capacity) async {
    final key = BusCapacity.normalize(capacity) ?? -1;
    if (key == -1) return defaultMarker();
    final cached = _cache[key];
    if (cached != null) return cached;

    final bytes = await _draw(key);
    _cache[key] = bytes;
    return bytes;
  }

  static Future<Uint8List> defaultMarker() async {
    if (_defaultBytes != null) return _defaultBytes!;
    _defaultBytes = await _draw(BusCapacity.medium);
    return _defaultBytes!;
  }

  static Future<Uint8List> _draw(int capacity) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ظل خفيف
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 4), 18, shadow);

    switch (capacity) {
      case BusCapacity.service:
        _drawService(canvas, size);
        break;
      case BusCapacity.large:
        _drawLargeBus(canvas, size);
        break;
      case BusCapacity.medium:
      default:
        _drawMediumBus(canvas, size);
        break;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  /// سرفيس: هيكل أصفر/برتقالي أقصر — يشبه الفان.
  static void _drawService(Canvas canvas, double size) {
    final cx = size / 2;
    final cy = size / 2;

    final body = Paint()..color = const Color(0xFFFFA000); // كهرماني
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 34, height: 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(rrect, body);

    // سقف أغمق قليلاً
    final roof = Paint()..color = const Color(0xFFF57C00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 8), width: 30, height: 10),
        const Radius.circular(4),
      ),
      roof,
    );

    // نوافذ
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

    // عجلات
    final wheel = Paint()..color = Colors.black87;
    canvas.drawCircle(Offset(cx - 10, cy + 12), 4.2, wheel);
    canvas.drawCircle(Offset(cx + 10, cy + 12), 4.2, wheel);

    // شارة صغيرة "س"
    final badge = Paint()..color = const Color(0xFFE65100);
    canvas.drawCircle(Offset(cx, cy + 6), 5.5, badge);
  }

  /// باص متوسط (23): أزرق كلاسيكي.
  static void _drawMediumBus(Canvas canvas, double size) {
    final cx = size / 2;
    final cy = size / 2;

    final body = Paint()..color = const Color(0xFF1565C0);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 40),
      const Radius.circular(7),
    );
    canvas.drawRRect(rrect, body);

    final window = Paint()..color = Colors.white.withValues(alpha: 0.9);
    // نافذتان عموديتان
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

  /// باص كبير (50): أطول وأخضر مميز مع 3 نوافذ.
  static void _drawLargeBus(Canvas canvas, double size) {
    final cx = size / 2;
    final cy = size / 2;

    final body = Paint()..color = const Color(0xFF2E7D32); // أخضر
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 36, height: 48),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, body);

    // شريط علوي
    final stripe = Paint()..color = const Color(0xFF1B5E20);
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
