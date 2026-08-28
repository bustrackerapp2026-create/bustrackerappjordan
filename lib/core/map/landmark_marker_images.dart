import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';
import 'maki_icons_data.dart';

/// معالم بأيقونات **Mapbox Maki الرسمية** (CC0).
///
/// أسلوب العرض: دائرة ملوّنة صلبة + رمز Maki أبيض حاد في الوسط،
/// بحجم أوضح وأقرب لأيقونات Mapbox Streets على الشاشة.
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  /// دقة عالية (96px) للوضوح على شاشات Retina ثم يُصغَّر عبر iconSize.
  static const double markerSize = 96;

  /// نصف قطر الدائرة الملوّنة داخل الصورة.
  static const double circleRadius = 28;

  /// حجم رسم رمز Maki داخل الدائرة (أكبر = أوضح).
  static const double iconDrawSize = 36;

  static const int labelTextColor = 0xFF333333;
  static const int labelHaloColor = 0xFFFFFFFF;
  static const double labelHaloWidth = 1.15;
  static const double labelLetterSpacing = 0.0;
  static const double labelMaxWidth = 7.5;

  static final Map<MapLandmarkType, Uint8List> _iconCache = {};

  /// أدنى زوم لظهور الأيقونة — مطابق تقريباً لكثافة POI في Mapbox Streets.
  /// عند التصغير تحت هذا المستوى تُحذف الأيقونة من الخريطة.
  static double minZoomFor(MapLandmarkType type) {
    switch (type) {
      // معالم كبرى: تظهر مبكراً نسبياً (مثل مطار/مستشفى في Streets)
      case MapLandmarkType.airport:
      case MapLandmarkType.university:
      case MapLandmarkType.hospital:
      case MapLandmarkType.stadium:
      case MapLandmarkType.trainStation:
        return 12.0;
      // معالم متوسطة الأهمية
      case MapLandmarkType.mosque:
      case MapLandmarkType.church:
      case MapLandmarkType.government:
      case MapLandmarkType.police:
      case MapLandmarkType.fireStation:
      case MapLandmarkType.school:
      case MapLandmarkType.college:
      case MapLandmarkType.medicalCenter:
      case MapLandmarkType.busStation:
      case MapLandmarkType.hotel:
      case MapLandmarkType.park:
      case MapLandmarkType.museum:
      case MapLandmarkType.attraction:
      case MapLandmarkType.zoo:
      case MapLandmarkType.embassy:
      case MapLandmarkType.beach:
        return 13.5;
      // تجاري وخدمات شائعة
      case MapLandmarkType.restaurant:
      case MapLandmarkType.supermarket:
      case MapLandmarkType.market:
      case MapLandmarkType.bank:
      case MapLandmarkType.fuel:
      case MapLandmarkType.pharmacy:
      case MapLandmarkType.clinic:
      case MapLandmarkType.library:
      case MapLandmarkType.cinema:
      case MapLandmarkType.gym:
      case MapLandmarkType.vehicleBridge:
      case MapLandmarkType.tunnel:
        return 14.5;
      // نقاط صغيرة — تختفي مبكراً عند التصغير
      case MapLandmarkType.cafe:
      case MapLandmarkType.fastFood:
      case MapLandmarkType.bakery:
      case MapLandmarkType.shop:
      case MapLandmarkType.clothing:
      case MapLandmarkType.convenience:
      case MapLandmarkType.parking:
      case MapLandmarkType.atm:
      case MapLandmarkType.chargingStation:
      case MapLandmarkType.kindergarten:
      case MapLandmarkType.dentist:
      case MapLandmarkType.postOffice:
      case MapLandmarkType.carRepair:
      case MapLandmarkType.carRental:
      case MapLandmarkType.playground:
      case MapLandmarkType.aquarium:
      case MapLandmarkType.house:
      case MapLandmarkType.taxi:
      case MapLandmarkType.bar:
        return 15.5;
      default:
        return 16.5;
    }
  }

  static double labelMinZoomFor(MapLandmarkType type) =>
      (minZoomFor(type) + 1.0).clamp(14.0, 17.5);

  static bool isVisibleAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= minZoomFor(type);

  static bool showLabelAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= labelMinZoomFor(type);

  /// مقياس PointAnnotation — الحجم النهائي على الشاشة أوضح وأقرب لـ Mapbox.
  /// 96px × 0.55 ≈ 53px قطر الدائرة على الشاشة (أكثر وضوحاً من السابق).
  static double iconSizeForZoom(double zoom) {
    final z = zoom.clamp(10.0, 20.0);
    if (z <= 12) return 0.55;
    if (z >= 17) return 0.85;
    return 0.55 + ((z - 12.0) / 5.0) * 0.30;
  }

  static double labeledIconSizeForZoom(double zoom) => iconSizeForZoom(zoom);
  static const double labelMinZoom = 13.5;
  static bool showLabelForZoom(double zoom) => zoom >= labelMinZoom;

  static double textSizeForZoom(double zoom) {
    if (zoom < 13.0) return 0;
    final z = zoom.clamp(13.0, 18.0);
    return 11.0 + ((z - 13.0) / 5.0) * 3.5;
  }

  static List<double> textOffsetForZoom(double zoom) {
    final y = 1.05 + ((zoom.clamp(13.0, 18.0) - 13.0) / 5.0) * 0.30;
    return [0.0, y];
  }

  /// اسم ملف Maki الرسمي المطابق للنوع.
  static String makiNameFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.restaurant:
        return 'restaurant';
      case MapLandmarkType.cafe:
        return 'cafe';
      case MapLandmarkType.fastFood:
        return 'fast-food';
      case MapLandmarkType.bakery:
        return 'bakery';
      case MapLandmarkType.bar:
        return 'bar';
      case MapLandmarkType.hotel:
        return 'lodging';
      case MapLandmarkType.house:
        return 'home';
      case MapLandmarkType.shop:
        return 'shop';
      case MapLandmarkType.supermarket:
        return 'grocery';
      case MapLandmarkType.clothing:
        return 'clothing-store';
      case MapLandmarkType.convenience:
        return 'shop';
      case MapLandmarkType.market:
        return 'shop';
      case MapLandmarkType.hospital:
        return 'hospital';
      case MapLandmarkType.medicalCenter:
        return 'hospital';
      case MapLandmarkType.pharmacy:
        return 'pharmacy';
      case MapLandmarkType.clinic:
        return 'doctor';
      case MapLandmarkType.dentist:
        return 'dentist';
      case MapLandmarkType.school:
        return 'school';
      case MapLandmarkType.university:
        return 'college';
      case MapLandmarkType.college:
        return 'college';
      case MapLandmarkType.kindergarten:
        return 'school';
      case MapLandmarkType.library:
        return 'library';
      case MapLandmarkType.mosque:
        return 'religious-muslim';
      case MapLandmarkType.church:
        return 'religious-christian';
      case MapLandmarkType.bank:
        return 'bank';
      case MapLandmarkType.atm:
        return 'bank';
      case MapLandmarkType.fuel:
        return 'fuel';
      case MapLandmarkType.chargingStation:
        return 'charging-station';
      case MapLandmarkType.parking:
        return 'parking';
      case MapLandmarkType.busStation:
        return 'bus';
      case MapLandmarkType.trainStation:
        return 'rail';
      case MapLandmarkType.airport:
        return 'airport';
      case MapLandmarkType.taxi:
        return 'car';
      case MapLandmarkType.roundabout:
        return 'marker';
      case MapLandmarkType.trafficLight:
        return 'caution';
      case MapLandmarkType.pedestrianBridge:
        return 'bridge';
      case MapLandmarkType.vehicleBridge:
        return 'bridge';
      case MapLandmarkType.crosswalk:
        return 'cross';
      case MapLandmarkType.tunnel:
        return 'tunnel';
      case MapLandmarkType.warningTriangle:
        return 'triangle';
      case MapLandmarkType.government:
        return 'town-hall';
      case MapLandmarkType.police:
        return 'police';
      case MapLandmarkType.fireStation:
        return 'fire-station';
      case MapLandmarkType.postOffice:
        return 'post';
      case MapLandmarkType.embassy:
        return 'town-hall';
      case MapLandmarkType.park:
        return 'park';
      case MapLandmarkType.playground:
        return 'playground';
      case MapLandmarkType.museum:
        return 'museum';
      case MapLandmarkType.cinema:
        return 'cinema';
      case MapLandmarkType.gym:
        return 'fitness-centre';
      case MapLandmarkType.stadium:
        return 'stadium';
      case MapLandmarkType.beach:
        return 'beach';
      case MapLandmarkType.zoo:
        return 'zoo';
      case MapLandmarkType.aquarium:
        return 'aquarium';
      case MapLandmarkType.attraction:
        return 'attraction';
      case MapLandmarkType.carRepair:
        return 'car-repair';
      case MapLandmarkType.carRental:
        return 'car-rental';
      case MapLandmarkType.laundry:
        return 'laundry';
      case MapLandmarkType.hairdresser:
        return 'hairdresser';
      case MapLandmarkType.barber:
        return 'hairdresser';
      case MapLandmarkType.beautySalon:
        return 'hairdresser';
      case MapLandmarkType.toilet:
        return 'toilet';
      case MapLandmarkType.other:
        return 'marker';
    }
  }

  static Color colorFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.restaurant:
      case MapLandmarkType.bar:
        return const Color(0xFFE55E5E);
      case MapLandmarkType.cafe:
      case MapLandmarkType.fastFood:
      case MapLandmarkType.bakery:
        return const Color(0xFFF0A000);
      case MapLandmarkType.hotel:
        return const Color(0xFF8B6BB5);
      case MapLandmarkType.house:
        return const Color(0xFF7A7A7A);
      case MapLandmarkType.shop:
      case MapLandmarkType.supermarket:
      case MapLandmarkType.clothing:
      case MapLandmarkType.convenience:
      case MapLandmarkType.market:
        return const Color(0xFFAC39AC);
      case MapLandmarkType.hospital:
      case MapLandmarkType.medicalCenter:
      case MapLandmarkType.pharmacy:
      case MapLandmarkType.clinic:
      case MapLandmarkType.dentist:
        return const Color(0xFFE55E5E);
      case MapLandmarkType.school:
      case MapLandmarkType.university:
      case MapLandmarkType.college:
      case MapLandmarkType.kindergarten:
      case MapLandmarkType.library:
        return const Color(0xFF3BB2D0);
      case MapLandmarkType.mosque:
        return const Color(0xFF56B881);
      case MapLandmarkType.church:
        return const Color(0xFF7A7A7A);
      case MapLandmarkType.bank:
      case MapLandmarkType.atm:
        return const Color(0xFF4264FB);
      case MapLandmarkType.fuel:
        return const Color(0xFFF0A000);
      case MapLandmarkType.chargingStation:
        return const Color(0xFF56B881);
      case MapLandmarkType.parking:
      case MapLandmarkType.busStation:
      case MapLandmarkType.trainStation:
        return const Color(0xFF4264FB);
      case MapLandmarkType.airport:
        return const Color(0xFF7A7A7A);
      case MapLandmarkType.taxi:
        return const Color(0xFFF0A000);
      case MapLandmarkType.police:
        return const Color(0xFF4264FB);
      case MapLandmarkType.fireStation:
        return const Color(0xFFE55E5E);
      case MapLandmarkType.park:
      case MapLandmarkType.playground:
      case MapLandmarkType.gym:
      case MapLandmarkType.zoo:
        return const Color(0xFF56B881);
      case MapLandmarkType.museum:
      case MapLandmarkType.cinema:
      case MapLandmarkType.attraction:
        return const Color(0xFF8B6BB5);
      case MapLandmarkType.stadium:
      case MapLandmarkType.beach:
      case MapLandmarkType.aquarium:
        return const Color(0xFF3BB2D0);
      default:
        return const Color(0xFF7A7A7A);
    }
  }

  /// للواجهة فقط (نموذج إضافة معلم).
  static IconData iconDataFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.mosque:
        return Icons.mosque;
      case MapLandmarkType.school:
        return Icons.school;
      case MapLandmarkType.police:
        return Icons.local_police;
      case MapLandmarkType.hospital:
        return Icons.local_hospital;
      default:
        return Icons.place;
    }
  }

  static Future<Uint8List> bytesFor(MapLandmarkType type) async {
    final hit = _iconCache[type];
    if (hit != null) return hit;
    final bytes = await _renderMakiBadge(type);
    _iconCache[type] = bytes;
    return bytes;
  }

  static Future<Uint8List> bytesWithLabel({
    required MapLandmarkType type,
    required String name,
    double fontSize = 28,
  }) =>
      bytesFor(type);

  static Future<void> preloadAll() async {
    for (final t in MapLandmarkType.values) {
      await bytesFor(t);
    }
  }

  static void clearCache() => _iconCache.clear();

  /// دائرة ملوّنة + رمز Maki أبيض حاد (بدون blur).
  static Future<Uint8List> _renderMakiBadge(MapLandmarkType type) async {
    final name = makiNameFor(type);
    final raw = MakiIcons.bytes(name) ?? MakiIcons.bytes('marker');
    final color = colorFor(type);

    if (raw == null) {
      return _fallbackDot(color);
    }

    try {
      final codec = await ui.instantiateImageCodec(raw);
      final frame = await codec.getNextFrame();
      final src = frame.image;
      final w = src.width;
      final h = src.height;
      final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) return _fallbackDot(color);

      // تحويل الرمز إلى أبيض صلب حاد (silhouette) مع الحفاظ على الشفافية
      final pixels = bd.buffer.asUint8List();
      for (var i = 0; i < pixels.length; i += 4) {
        final a = pixels[i + 3];
        if (a < 12) {
          pixels[i] = 0;
          pixels[i + 1] = 0;
          pixels[i + 2] = 0;
          pixels[i + 3] = 0;
          continue;
        }
        final lum = (pixels[i] + pixels[i + 1] + pixels[i + 2]) / 3.0;
        // البكسلات الداكنة = شكل الرمز → أبيض صلب
        // البكسلات الفاتحة/شبه الشفافة → تُزال
        if (lum > 200) {
          pixels[i + 3] = 0;
          continue;
        }
        // حافة أكثر صلابة (أقل تدرجاً) لوضوح أفضل عند التصغير
        final strength = (1.0 - (lum / 200.0)).clamp(0.0, 1.0);
        final outA = (a * (0.75 + 0.25 * strength)).round().clamp(0, 255);
        pixels[i] = 255;
        pixels[i + 1] = 255;
        pixels[i + 2] = 255;
        pixels[i + 3] = outA;
      }

      final whiteCodec = await ui.ImageDescriptor.raw(
        await ui.ImmutableBuffer.fromUint8List(pixels),
        width: w,
        height: h,
        pixelFormat: ui.PixelFormat.rgba8888,
      ).instantiateCodec();
      final whiteFrame = await whiteCodec.getNextFrame();
      final whiteIcon = whiteFrame.image;

      const size = markerSize;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size / 2, size / 2);

      // ظل خفيف
      canvas.drawCircle(
        center.translate(0, 1.8),
        circleRadius,
        Paint()..color = const Color(0x40000000),
      );

      // الدائرة الملوّنة الصلبة
      canvas.drawCircle(
        center,
        circleRadius,
        Paint()..color = color,
      );

      // حد أبيض أوضح (متناسب مع الحجم الأكبر)
      canvas.drawCircle(
        center,
        circleRadius,
        Paint()
          ..color = const Color(0xF0FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );

      // رمز Maki أبيض في الوسط
      final dest = Rect.fromCenter(
        center: center,
        width: iconDrawSize,
        height: iconDrawSize,
      );
      paintImage(
        canvas: canvas,
        rect: dest,
        image: whiteIcon,
        filterQuality: FilterQuality.medium,
      );

      final picture = recorder.endRecording();
      final out = await picture.toImage(size.toInt(), size.toInt());
      final outBd = await out.toByteData(format: ui.ImageByteFormat.png);
      return outBd!.buffer.asUint8List();
    } catch (_) {
      return _fallbackDot(color);
    }
  }

  static Future<Uint8List> _fallbackDot(Color color) async {
    const size = markerSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final c = Offset(size / 2, size / 2);
    canvas.drawCircle(c.translate(0, 1.5), circleRadius, Paint()..color = const Color(0x40000000));
    canvas.drawCircle(c, circleRadius, Paint()..color = color);
    canvas.drawCircle(
      c,
      circleRadius,
      Paint()
        ..color = const Color(0xF0FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }
}
