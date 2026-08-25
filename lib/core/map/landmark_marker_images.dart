import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';

/// أيقونات معالم المشروع — أسلوب Google Maps POI.
/// الأسماء تُرسم بخط النظام العربي (نفس خط واجهة التطبيق) مع RTL.
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  static const double markerSize = 96;

  static const int labelTextColor = 0xFF3C4043;
  static const int labelHaloColor = 0xFFFFFFFF;
  static const double labelHaloWidth = 1.1;
  static const double labelLetterSpacing = 0.01;
  static const double labelMaxWidth = 9;

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
        return 12.2;

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
        return 13.4;

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
        return 14.4;

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
        return 15.4;
    }
  }

  static double labelMinZoomFor(MapLandmarkType type) {
    final iconMin = minZoomFor(type);
    return (iconMin + 0.85).clamp(13.0, 16.0);
  }

  static bool isVisibleAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= minZoomFor(type);

  static bool showLabelAtZoom(MapLandmarkType type, double zoom) =>
      zoom >= labelMinZoomFor(type);

  static double iconSizeForZoom(double zoom) {
    if (zoom <= 11.5) return 0.40;
    if (zoom <= 12.5) return 0.44;
    if (zoom <= 13.5) return 0.48;
    if (zoom <= 14.5) return 0.52;
    if (zoom <= 15.5) return 0.56;
    if (zoom <= 16.5) return 0.60;
    return 0.64;
  }

  /// حجم أيقونة مركّبة (أيقونة + اسم مرسوم)
  static double labeledIconSizeForZoom(double zoom) {
    if (zoom <= 13.5) return 0.55;
    if (zoom <= 15.0) return 0.62;
    if (zoom <= 16.5) return 0.70;
    return 0.78;
  }

  static const double labelMinZoom = 13.5;

  static bool showLabelForZoom(double zoom) => zoom >= labelMinZoom;

  static double textSizeForZoom(double zoom) {
    if (zoom < 13.2) return 0;
    if (zoom < 14.5) return 12.0;
    if (zoom < 15.8) return 13.0;
    return 13.5;
  }

  static List<double> textOffsetForZoom(double zoom) {
    final y = zoom >= 16 ? 1.15 : (zoom >= 14.5 ? 1.08 : 1.00);
    return [0.0, y];
  }

  static Color colorFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.restaurant:
        return const Color(0xFFEA4335);
      case MapLandmarkType.cafe:
        return const Color(0xFFEA8600);
      case MapLandmarkType.fastFood:
        return const Color(0xFFEA8600);
      case MapLandmarkType.bakery:
        return const Color(0xFFEA8600);
      case MapLandmarkType.bar:
        return const Color(0xFFEA4335);
      case MapLandmarkType.hotel:
        return const Color(0xFF7B1FA2);
      case MapLandmarkType.house:
        return const Color(0xFF5F6368);
      case MapLandmarkType.shop:
        return const Color(0xFF9C27B0);
      case MapLandmarkType.supermarket:
        return const Color(0xFF9C27B0);
      case MapLandmarkType.clothing:
        return const Color(0xFF9C27B0);
      case MapLandmarkType.convenience:
        return const Color(0xFF9C27B0);
      case MapLandmarkType.market:
        return const Color(0xFF9C27B0);
      case MapLandmarkType.hospital:
        return const Color(0xFFEA4335);
      case MapLandmarkType.medicalCenter:
        return const Color(0xFFEA4335);
      case MapLandmarkType.pharmacy:
        return const Color(0xFFEA4335);
      case MapLandmarkType.clinic:
        return const Color(0xFFEA4335);
      case MapLandmarkType.dentist:
        return const Color(0xFFEA4335);
      case MapLandmarkType.school:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.university:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.college:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.kindergarten:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.library:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.mosque:
        return const Color(0xFF188038);
      case MapLandmarkType.church:
        return const Color(0xFF5F6368);
      case MapLandmarkType.bank:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.atm:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.fuel:
        return const Color(0xFFEA8600);
      case MapLandmarkType.chargingStation:
        return const Color(0xFF188038);
      case MapLandmarkType.parking:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.busStation:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.trainStation:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.airport:
        return const Color(0xFF5F6368);
      case MapLandmarkType.taxi:
        return const Color(0xFFF9AB00);
      case MapLandmarkType.roundabout:
        return const Color(0xFF5F6368);
      case MapLandmarkType.trafficLight:
        return const Color(0xFFEA4335);
      case MapLandmarkType.pedestrianBridge:
        return const Color(0xFF188038);
      case MapLandmarkType.vehicleBridge:
        return const Color(0xFF5F6368);
      case MapLandmarkType.crosswalk:
        return const Color(0xFF188038);
      case MapLandmarkType.tunnel:
        return const Color(0xFF5F6368);
      case MapLandmarkType.warningTriangle:
        return const Color(0xFFF9AB00);
      case MapLandmarkType.government:
        return const Color(0xFF5F6368);
      case MapLandmarkType.police:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.fireStation:
        return const Color(0xFFEA4335);
      case MapLandmarkType.postOffice:
        return const Color(0xFF5F6368);
      case MapLandmarkType.embassy:
        return const Color(0xFF5F6368);
      case MapLandmarkType.park:
        return const Color(0xFF188038);
      case MapLandmarkType.playground:
        return const Color(0xFF188038);
      case MapLandmarkType.museum:
        return const Color(0xFF7B1FA2);
      case MapLandmarkType.cinema:
        return const Color(0xFF7B1FA2);
      case MapLandmarkType.gym:
        return const Color(0xFF188038);
      case MapLandmarkType.stadium:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.beach:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.zoo:
        return const Color(0xFF188038);
      case MapLandmarkType.aquarium:
        return const Color(0xFF1A73E8);
      case MapLandmarkType.attraction:
        return const Color(0xFF7B1FA2);
      case MapLandmarkType.carRepair:
        return const Color(0xFF5F6368);
      case MapLandmarkType.carRental:
        return const Color(0xFF5F6368);
      case MapLandmarkType.laundry:
        return const Color(0xFF5F6368);
      case MapLandmarkType.hairdresser:
        return const Color(0xFFEA4335);
      case MapLandmarkType.barber:
        return const Color(0xFF5F6368);
      case MapLandmarkType.beautySalon:
        return const Color(0xFFEA4335);
      case MapLandmarkType.toilet:
        return const Color(0xFF5F6368);
      case MapLandmarkType.other:
        return const Color(0xFF5F6368);
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
    final bytes = await _renderIconOnly(type);
    _iconCache[type] = bytes;
    return bytes;
  }

  /// أيقونة + اسم عربي بخط النظام (نفس خط التطبيق) مع تشكيل RTL صحيح.
  static Future<Uint8List> bytesWithLabel({
    required MapLandmarkType type,
    required String name,
    double fontSize = 13,
  }) async {
    final safe = name.trim();
    if (safe.isEmpty) return bytesFor(type);

    final sizeKey = fontSize.round();
    final cacheKey = '${type.name}_${safe.hashCode}_f$sizeKey';
    final hit = _labeledCache[cacheKey];
    if (hit != null) return hit;

    final bytes = await _renderIconWithLabel(type, safe, fontSize);
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

  static Future<Uint8List> _renderIconOnly(MapLandmarkType type) async {
    const size = markerSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = colorFor(type);

    const radius = 36.0;
    const inner = 30.5;
    final center = Offset(size / 2, size / 2);

    final shadow = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    canvas.drawCircle(center.translate(0, 1.0), radius, shadow);

    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, inner, Paint()..color = color);

    final icon = iconDataFor(type);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 30,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2 - 0.5),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  /// رسم أيقونة + تسمية عربية بخط النظام (تشكيل طبيعي للعربية).
  static Future<Uint8List> _renderIconWithLabel(
    MapLandmarkType type,
    String name,
    double fontSize,
  ) async {
    const iconBox = 96.0;
    final maxLabelWidth = 160.0;

    final display = name.length > 18 ? '${name.substring(0, 17)}…' : name;

    // خط النظام — نفس خط واجهة Flutter العربية
    final namePainter = TextPainter(
      text: TextSpan(
        text: display,
        style: TextStyle(
          color: const Color(labelTextColor),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.15,
          // بدون fontFamily = خط النظام (مثل باقي التطبيق)
          shadows: const [
            Shadow(
              color: Color(0xFFFFFFFF),
              blurRadius: 2.5,
              offset: Offset(0, 0),
            ),
            Shadow(
              color: Color(0xFFFFFFFF),
              blurRadius: 1.2,
              offset: Offset(0.5, 0.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxLabelWidth);

    final totalWidth =
        (namePainter.width + 16).clamp(iconBox, maxLabelWidth + 8);
    final totalHeight = iconBox + namePainter.height + 10;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // أيقونة في الأعلى
    final color = colorFor(type);
    final center = Offset(totalWidth / 2, iconBox / 2);
    const radius = 36.0;
    const inner = 30.5;

    final shadow = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    canvas.drawCircle(center.translate(0, 1.0), radius, shadow);
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, inner, Paint()..color = color);

    final icon = iconDataFor(type);
    final iconTp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 30,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconTp.paint(
      canvas,
      Offset(
        center.dx - iconTp.width / 2,
        center.dy - iconTp.height / 2 - 0.5,
      ),
    );

    // الاسم أسفل الأيقونة — خط عربي طبيعي
    namePainter.paint(
      canvas,
      Offset(
        (totalWidth - namePainter.width) / 2,
        iconBox - 4,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      totalWidth.ceil(),
      totalHeight.ceil(),
    );
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }
}
