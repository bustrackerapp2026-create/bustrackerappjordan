import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';

/// أيقونات معالم — حجم وخط ومنحنى زوم قريب من Mapbox Streets POI.
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  /// صورة المصدر ~حجم سبرايت Mapbox (Maki تقريباً 15–22px عند العرض)
  static const double markerSize = 48;

  /// نص POI Mapbox: رمادي غامق + هالة بيضاء
  static const int labelTextColor = 0xFF333333;
  static const int labelHaloColor = 0xFFFFFFFF;
  static const double labelHaloWidth = 1.15;
  static const double labelLetterSpacing = 0.0;
  static const double labelMaxWidth = 7.5;

  static final Map<MapLandmarkType, Uint8List> _iconCache = {};
  static final Map<String, Uint8List> _labeledCache = {};

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

  /// التسمية تظهر بعد الأيقونة بقليل (كـ Mapbox)
  static double labelMinZoomFor(MapLandmarkType type) {
    return (minZoomFor(type) + 1.0).clamp(13.5, 16.5);
  }

  static bool isVisibleAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= minZoomFor(type);

  static bool showLabelAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= labelMinZoomFor(type);

  ///
  /// حجم الأيقونة مقابل الزوم — منحنى قريب من Mapbox:
  /// `interpolate linear zoom: [10→0.36] … [18→0.72]`
  /// مع صورة 48px → عرض تقريبي 17–35 بكسل على الشاشة.
  ///
  static double iconSizeForZoom(double zoom) {
    final z = zoom.clamp(10.0, 20.0);
    if (z <= 10) return 0.36;
    if (z >= 18) return 0.72;
    // خطي سلس بين 10 و 18
    return 0.36 + ((z - 10.0) / 8.0) * 0.36;
  }

  static double labeledIconSizeForZoom(double zoom) => iconSizeForZoom(zoom);

  static const double labelMinZoom = 13.5;

  static bool showLabelForZoom(double zoom) => zoom >= labelMinZoom;

  ///
  /// حجم خط الاسم — Mapbox POI غالباً ~10–13:
  /// `interpolate linear zoom: [13→10] [18→13]`
  ///
  static double textSizeForZoom(double zoom) {
    if (zoom < 13.0) return 0;
    final z = zoom.clamp(13.0, 18.0);
    return 10.0 + ((z - 13.0) / 5.0) * 3.0;
  }

  static List<double> textOffsetForZoom(double zoom) {
    // إزاحة تحت الرمز بمقدار قريب من Mapbox text-offset
    final y = 0.85 + ((zoom.clamp(13.0, 18.0) - 13.0) / 5.0) * 0.25;
    return [0.0, y];
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
    final bytes = await _renderMapboxStyleIcon(type);
    _iconCache[type] = bytes;
    return bytes;
  }

  static Future<Uint8List> bytesWithLabel({
    required MapLandmarkType type,
    required String name,
    double fontSize = 28,
  }) async {
    final safe = name.trim();
    if (safe.isEmpty) return bytesFor(type);
    final sizeKey = fontSize.round();
    final cacheKey = '${type.name}_${safe.hashCode}_f$sizeKey';
    final hit = _labeledCache[cacheKey];
    if (hit != null) return hit;
    final bytes = await bytesFor(type);
    if (_labeledCache.length > 200) _labeledCache.clear();
    _labeledCache[cacheKey] = bytes;
    return bytes;
  }

  static Future<void> preloadAll() async {
    for (final t in MapLandmarkType.values) {
      await bytesFor(t);
    }
  }

  static void clearCache() {
    _iconCache.clear();
    _labeledCache.clear();
  }

  static Future<Uint8List> _renderMapboxStyleIcon(MapLandmarkType type) async {
    const size = markerSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = colorFor(type);
    final center = Offset(size / 2, size / 2);

    // هالة خفيفة فقط (بدون دائرة ملونة)
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
            Shadow(
              color: Color(0xCCFFFFFF),
              blurRadius: 0.5,
              offset: Offset(0.4, 0.4),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }
}
