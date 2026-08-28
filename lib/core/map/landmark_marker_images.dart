import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';

///
/// معالم الخريطة — أقرب ما يمكن لسلوك Mapbox Streets:
/// 1) **Sprite Atlas**: كل الرموز في صورة واحدة ثم تُقص حسب النوع (أداء أوضح).
/// 2) **حجم ديناميكي**: iconSize / textSize يتغيران مع الزوم مثل POI.
///
/// ملاحظة: رموز Mapbox الأصلية اسمها **Maki** (مجموعة مفتوحة المصدر 15×15).
/// نحن نرسم رموزاً بنفس الفكرة والحجم التقريبي لأن دمج ملفات SVG الرسمية
/// يحتاج أصولاً ثابتة في المشروع؛ الـ Atlas يحاكي آلية الـ sprite.
///
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  /// خلية واحدة في الـ Atlas ≈ حجم سبرايت Maki بعد التكبير للوضوح على الشاشات الحديثة
  static const int cellSize = 48;
  static const int atlasColumns = 8;

  static const int labelTextColor = 0xFF333333;
  static const int labelHaloColor = 0xFFFFFFFF;
  static const double labelHaloWidth = 1.15;
  static const double labelLetterSpacing = 0.0;
  static const double labelMaxWidth = 7.5;

  static final Map<MapLandmarkType, Uint8List> _iconCache = {};
  static Uint8List? _atlasPng;
  static bool _atlasBuilding = false;

  // ─── ظهور حسب الزوم (LOD شبيه Mapbox) ───────────────────────────

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
      case MapLandmarkType.laundry:
      case MapLandmarkType.hairdresser:
      case MapLandmarkType.barber:
      case MapLandmarkType.beautySalon:
      case MapLandmarkType.toilet:
      case MapLandmarkType.roundabout:
      case MapLandmarkType.trafficLight:
      case MapLandmarkType.pedestrianBridge:
      case MapLandmarkType.crosswalk:
      case MapLandmarkType.warningTriangle:
      case MapLandmarkType.other:
        return 15.5;
    }
  }

  static double labelMinZoomFor(MapLandmarkType type) =>
      (minZoomFor(type) + 1.0).clamp(13.5, 16.5);

  static bool isVisibleAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= minZoomFor(type);

  static bool showLabelAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= labelMinZoomFor(type);

  /// حساب ديناميكي لحجم الأيقونة (مثل interpolate في Mapbox Style).
  /// زوم 10 → ~0.36 | زوم 18 → ~0.72  (مع خلية 48px ≈ 17–35 بكسل شاشة).
  static double iconSizeForZoom(double zoom) {
    final z = zoom.clamp(10.0, 20.0);
    if (z <= 10) return 0.36;
    if (z >= 18) return 0.72;
    return 0.36 + ((z - 10.0) / 8.0) * 0.36;
  }

  static double labeledIconSizeForZoom(double zoom) => iconSizeForZoom(zoom);

  static const double labelMinZoom = 13.5;
  static bool showLabelForZoom(double zoom) => zoom >= labelMinZoom;

  /// حساب ديناميكي لحجم الخط (Mapbox POI تقريباً 10→13).
  static double textSizeForZoom(double zoom) {
    if (zoom < 13.0) return 0;
    final z = zoom.clamp(13.0, 18.0);
    return 10.0 + ((z - 13.0) / 5.0) * 3.0;
  }

  static List<double> textOffsetForZoom(double zoom) {
    final y = 0.85 + ((zoom.clamp(13.0, 18.0) - 13.0) / 5.0) * 0.25;
    return [0.0, y];
  }

  /// اسم مقارب لرموز Maki (للتوثيق والمطابقة البصرية).
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
        return 'place-of-worship';
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
      case MapLandmarkType.police:
        return 'police';
      case MapLandmarkType.fireStation:
        return 'fire-station';
      case MapLandmarkType.postOffice:
        return 'post';
      case MapLandmarkType.embassy:
        return 'town-hall';
      case MapLandmarkType.government:
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
      case MapLandmarkType.toilet:
        return 'toilet';
      default:
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
      case MapLandmarkType.roundabout:
      case MapLandmarkType.vehicleBridge:
      case MapLandmarkType.tunnel:
        return const Color(0xFF7A7A7A);
      case MapLandmarkType.trafficLight:
        return const Color(0xFFE55E5E);
      case MapLandmarkType.pedestrianBridge:
      case MapLandmarkType.crosswalk:
        return const Color(0xFF56B881);
      case MapLandmarkType.warningTriangle:
        return const Color(0xFFF0A000);
      case MapLandmarkType.government:
      case MapLandmarkType.postOffice:
      case MapLandmarkType.embassy:
        return const Color(0xFF7A7A7A);
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
      case MapLandmarkType.carRepair:
      case MapLandmarkType.carRental:
      case MapLandmarkType.laundry:
      case MapLandmarkType.barber:
      case MapLandmarkType.toilet:
      case MapLandmarkType.other:
        return const Color(0xFF7A7A7A);
      case MapLandmarkType.hairdresser:
      case MapLandmarkType.beautySalon:
        return const Color(0xFFE55E5E);
    }
  }

  static IconData iconDataFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.restaurant:
        return Icons.restaurant;
      case MapLandmarkType.cafe:
        return Icons.local_cafe;
      case MapLandmarkType.fastFood:
        return Icons.fastfood;
      case MapLandmarkType.bakery:
        return Icons.bakery_dining;
      case MapLandmarkType.bar:
        return Icons.local_bar;
      case MapLandmarkType.hotel:
        return Icons.hotel;
      case MapLandmarkType.house:
        return Icons.home;
      case MapLandmarkType.shop:
        return Icons.storefront;
      case MapLandmarkType.supermarket:
        return Icons.local_grocery_store;
      case MapLandmarkType.clothing:
        return Icons.checkroom;
      case MapLandmarkType.convenience:
        return Icons.store;
      case MapLandmarkType.market:
        return Icons.store_mall_directory;
      case MapLandmarkType.hospital:
        return Icons.local_hospital;
      case MapLandmarkType.medicalCenter:
        return Icons.health_and_safety;
      case MapLandmarkType.pharmacy:
        return Icons.local_pharmacy;
      case MapLandmarkType.clinic:
        return Icons.medical_services;
      case MapLandmarkType.dentist:
        return Icons.medical_services_outlined;
      case MapLandmarkType.school:
        return Icons.school;
      case MapLandmarkType.university:
        return Icons.account_balance;
      case MapLandmarkType.college:
        return Icons.school_outlined;
      case MapLandmarkType.kindergarten:
        return Icons.child_care;
      case MapLandmarkType.library:
        return Icons.local_library;
      case MapLandmarkType.mosque:
        return Icons.mosque;
      case MapLandmarkType.church:
        return Icons.church;
      case MapLandmarkType.bank:
        return Icons.account_balance_wallet;
      case MapLandmarkType.atm:
        return Icons.atm;
      case MapLandmarkType.fuel:
        return Icons.local_gas_station;
      case MapLandmarkType.chargingStation:
        return Icons.ev_station;
      case MapLandmarkType.parking:
        return Icons.local_parking;
      case MapLandmarkType.busStation:
        return Icons.directions_bus;
      case MapLandmarkType.trainStation:
        return Icons.train;
      case MapLandmarkType.airport:
        return Icons.flight;
      case MapLandmarkType.taxi:
        return Icons.local_taxi;
      case MapLandmarkType.roundabout:
        return Icons.roundabout_left;
      case MapLandmarkType.trafficLight:
        return Icons.traffic;
      case MapLandmarkType.pedestrianBridge:
        return Icons.directions_walk;
      case MapLandmarkType.vehicleBridge:
        return Icons.directions_car;
      case MapLandmarkType.crosswalk:
        return Icons.transfer_within_a_station;
      case MapLandmarkType.tunnel:
        return Icons.subway;
      case MapLandmarkType.warningTriangle:
        return Icons.warning_amber;
      case MapLandmarkType.government:
        return Icons.account_balance_outlined;
      case MapLandmarkType.police:
        return Icons.local_police;
      case MapLandmarkType.fireStation:
        return Icons.local_fire_department;
      case MapLandmarkType.postOffice:
        return Icons.local_post_office;
      case MapLandmarkType.embassy:
        return Icons.flag;
      case MapLandmarkType.park:
        return Icons.park;
      case MapLandmarkType.playground:
        return Icons.toys;
      case MapLandmarkType.museum:
        return Icons.museum;
      case MapLandmarkType.cinema:
        return Icons.movie;
      case MapLandmarkType.gym:
        return Icons.fitness_center;
      case MapLandmarkType.stadium:
        return Icons.stadium;
      case MapLandmarkType.beach:
        return Icons.beach_access;
      case MapLandmarkType.zoo:
        return Icons.pets;
      case MapLandmarkType.aquarium:
        return Icons.water;
      case MapLandmarkType.attraction:
        return Icons.attractions;
      case MapLandmarkType.carRepair:
        return Icons.car_repair;
      case MapLandmarkType.carRental:
        return Icons.directions_car_filled;
      case MapLandmarkType.laundry:
        return Icons.local_laundry_service;
      case MapLandmarkType.hairdresser:
        return Icons.content_cut;
      case MapLandmarkType.barber:
        return Icons.face_retouching_natural;
      case MapLandmarkType.beautySalon:
        return Icons.spa;
      case MapLandmarkType.toilet:
        return Icons.wc;
      case MapLandmarkType.other:
        return Icons.place;
    }
  }

  static Future<Uint8List> bytesFor(MapLandmarkType type) async {
    final hit = _iconCache[type];
    if (hit != null) return hit;
    await _ensureAtlas();
    final bytes = await _cropFromAtlas(type);
    _iconCache[type] = bytes;
    return bytes;
  }

  static Future<Uint8List> bytesWithLabel({
    required MapLandmarkType type,
    required String name,
    double fontSize = 28,
  }) async {
    return bytesFor(type);
  }

  static Future<void> preloadAll() async {
    await _ensureAtlas();
    for (final t in MapLandmarkType.values) {
      await bytesFor(t);
    }
  }

  static void clearCache() {
    _iconCache.clear();
    _atlasPng = null;
  }

  static int _indexOf(MapLandmarkType type) =>
      MapLandmarkType.values.indexOf(type);

  static Future<void> _ensureAtlas() async {
    if (_atlasPng != null) return;
    if (_atlasBuilding) {
      while (_atlasBuilding) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      return;
    }
    _atlasBuilding = true;
    try {
      _atlasPng = await _buildAtlasPng();
    } finally {
      _atlasBuilding = false;
    }
  }

  /// Sprite map: شبكة واحدة لكل أنواع المعالم.
  static Future<Uint8List> _buildAtlasPng() async {
    final types = MapLandmarkType.values;
    final count = types.length;
    final cols = atlasColumns;
    final rows = (count / cols).ceil();
    final width = cols * cellSize;
    final height = rows * cellSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (var i = 0; i < count; i++) {
      final type = types[i];
      final col = i % cols;
      final row = i ~/ cols;
      final origin = Offset(col * cellSize.toDouble(), row * cellSize.toDouble());
      _paintIconInCell(canvas, type, origin);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  static void _paintIconInCell(
    Canvas canvas,
    MapLandmarkType type,
    Offset origin,
  ) {
    final color = colorFor(type);
    final center = origin + Offset(cellSize / 2, cellSize / 2);

    final halo = Paint()
      ..color = const Color(0xEEFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    canvas.drawCircle(center, 12.5, halo);

    final softShadow = Paint()
      ..color = const Color(0x18000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    canvas.drawCircle(center.translate(0, 0.5), 11.0, softShadow);

    final icon = iconDataFor(type);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 18,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          fontWeight: FontWeight.w500,
          shadows: const [
            Shadow(
              color: Color(0xFFFFFFFF),
              blurRadius: 1.0,
              offset: Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        origin.dx + (cellSize - tp.width) / 2,
        origin.dy + (cellSize - tp.height) / 2,
      ),
    );
  }

  static Future<Uint8List> _cropFromAtlas(MapLandmarkType type) async {
    final atlasBytes = _atlasPng;
    if (atlasBytes == null) {
      return _renderSingleFallback(type);
    }

    final codec = await ui.instantiateImageCodec(atlasBytes);
    final frame = await codec.getNextFrame();
    final atlas = frame.image;

    final i = _indexOf(type);
    final col = i % atlasColumns;
    final row = i ~/ atlasColumns;
    final src = Rect.fromLTWH(
      col * cellSize.toDouble(),
      row * cellSize.toDouble(),
      cellSize.toDouble(),
      cellSize.toDouble(),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      atlas,
      src,
      Rect.fromLTWH(0, 0, cellSize.toDouble(), cellSize.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(cellSize, cellSize);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  static Future<Uint8List> _renderSingleFallback(MapLandmarkType type) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintIconInCell(canvas, type, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(cellSize, cellSize);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }
}
