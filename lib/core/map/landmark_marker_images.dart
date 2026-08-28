import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';
import 'maki_icons_data.dart';

/// معالم بأيقونات **Mapbox Maki الرسمية** (CC0) + حجم ديناميكي حسب الزوم.
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  static const double markerSize = 48;

  static const int labelTextColor = 0xFF333333;
  static const int labelHaloColor = 0xFFFFFFFF;
  static const double labelHaloWidth = 1.15;
  static const double labelLetterSpacing = 0.0;
  static const double labelMaxWidth = 7.5;

  static final Map<MapLandmarkType, Uint8List> _iconCache = {};

  static double minZoomFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.airport:
      case MapLandmarkType.university:
      case MapLandmarkType.hospital:
      case MapLandmarkType.stadium:
      case MapLandmarkType.trainStation:
        return 11.0;
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
        return 12.5;
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
        return 13.5;
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
        return 14.5;
      default:
        return 15.5;
    }
  }

  static double labelMinZoomFor(MapLandmarkType type) =>
      (minZoomFor(type) + 1.0).clamp(13.5, 16.5);

  static bool isVisibleAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= minZoomFor(type);

  static bool showLabelAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= labelMinZoomFor(type);

  static double iconSizeForZoom(double zoom) {
    final z = zoom.clamp(10.0, 20.0);
    if (z <= 10) return 0.36;
    if (z >= 18) return 0.72;
    return 0.36 + ((z - 10.0) / 8.0) * 0.36;
  }

  static double labeledIconSizeForZoom(double zoom) => iconSizeForZoom(zoom);
  static const double labelMinZoom = 13.5;
  static bool showLabelForZoom(double zoom) => zoom >= labelMinZoom;

  static double textSizeForZoom(double zoom) {
    if (zoom < 13.0) return 0;
    final z = zoom.clamp(13.0, 18.0);
    return 10.0 + ((z - 13.0) / 5.0) * 3.0;
  }

  static List<double> textOffsetForZoom(double zoom) {
    final y = 0.85 + ((zoom.clamp(13.0, 18.0) - 13.0) / 5.0) * 0.25;
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
    final bytes = await _renderMakiColored(type);
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

  static Future<Uint8List> _renderMakiColored(MapLandmarkType type) async {
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

      final pixels = bd.buffer.asUint8List();
      final r = (color.r * 255.0).round().clamp(0, 255);
      final g = (color.g * 255.0).round().clamp(0, 255);
      final b = (color.b * 255.0).round().clamp(0, 255);

      // تلوين بكسلات الرمز (الأسود/الرمادي) بلون الفئة + الحفاظ على الشفافية
      for (var i = 0; i < pixels.length; i += 4) {
        final a = pixels[i + 3];
        if (a < 8) continue;
        final lum = (pixels[i] + pixels[i + 1] + pixels[i + 2]) / 3.0;
        if (lum > 240 && a < 200) {
          // خلفية شبه بيضاء نتركها
          continue;
        }
        final t = (1.0 - (lum / 255.0)).clamp(0.35, 1.0);
        pixels[i] = (r * t).round().clamp(0, 255);
        pixels[i + 1] = (g * t).round().clamp(0, 255);
        pixels[i + 2] = (b * t).round().clamp(0, 255);
      }

      final colored = await ui.ImageDescriptor.raw(
        await ui.ImmutableBuffer.fromUint8List(pixels),
        width: w,
        height: h,
        pixelFormat: ui.PixelFormat.rgba8888,
      ).instantiateCodec();
      final coloredFrame = await colored.getNextFrame();
      final coloredImg = coloredFrame.image;

      const size = markerSize;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size / 2, size / 2);

      // هالة بيضاء خفيفة للقراءة على الخريطة
      canvas.drawCircle(
        center,
        14,
        Paint()
          ..color = const Color(0xF2FFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );

      final dest = Rect.fromCenter(center: center, width: 28, height: 28);
      paintImage(
        canvas: canvas,
        rect: dest,
        image: coloredImg,
        filterQuality: FilterQuality.high,
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
    canvas.drawCircle(c, 10, Paint()..color = color);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }
}
