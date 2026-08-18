import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';

/// أيقونات معالم المشروع — تُولَّد مرة وتُخزَّن في الذاكرة.
/// أسلوب قريب من POI Mapbox (دائرة ملونة + رمز أبيض) بحجم موحّد للخريطة.
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  static const double markerSize = 88;

  static final Map<MapLandmarkType, Uint8List> _cache = {};

  /// ألوان قريبة من فئات POI في Mapbox Streets.
  static Color colorFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.mosque:
        return const Color(0xFF00897B); // teal — place of worship
      case MapLandmarkType.restaurant:
        return const Color(0xFFFB8C00); // orange — food
      case MapLandmarkType.cafe:
        return const Color(0xFFEF6C00); // deep orange — cafe
      case MapLandmarkType.university:
        return const Color(0xFF5E35B1); // deep purple — education
      case MapLandmarkType.hospital:
        return const Color(0xFFE53935); // red — medical
      case MapLandmarkType.pharmacy:
        return const Color(0xFFD81B60); // pink — pharmacy
      case MapLandmarkType.school:
        return const Color(0xFF1E88E5); // blue — school
      case MapLandmarkType.shop:
        return const Color(0xFF8E24AA); // purple — shop
      case MapLandmarkType.supermarket:
        return const Color(0xFF7B1FA2); // deep purple — grocery
      case MapLandmarkType.park:
        return const Color(0xFF2E7D32); // green — park
      case MapLandmarkType.government:
        return const Color(0xFF546E7A); // blue-grey — civic
      case MapLandmarkType.bank:
        return const Color(0xFF1565C0); // blue — bank
      case MapLandmarkType.atm:
        return const Color(0xFF0277BD); // light blue — atm
      case MapLandmarkType.hotel:
        return const Color(0xFF6A1B9A); // purple — lodging
      case MapLandmarkType.fuel:
        return const Color(0xFFF57C00); // amber — fuel
      case MapLandmarkType.parking:
        return const Color(0xFF3949AB); // indigo — parking
      case MapLandmarkType.busStation:
        return const Color(0xFF00838F); // cyan — transit
      case MapLandmarkType.police:
        return const Color(0xFF283593); // indigo dark — police
      case MapLandmarkType.postOffice:
        return const Color(0xFF455A64); // blue-grey — post
      case MapLandmarkType.library:
        return const Color(0xFF4527A0); // deep purple — library
      case MapLandmarkType.museum:
        return const Color(0xFF6D4C41); // brown — museum
      case MapLandmarkType.cinema:
        return const Color(0xFFAD1457); // pink — entertainment
      case MapLandmarkType.gym:
        return const Color(0xFF00897B); // teal — fitness
      case MapLandmarkType.church:
        return const Color(0xFF5D4037); // brown — church
      case MapLandmarkType.airport:
        return const Color(0xFF37474F); // blue-grey dark — airport
      case MapLandmarkType.carRepair:
        return const Color(0xFF616161); // grey — car repair
      case MapLandmarkType.other:
        return const Color(0xFF607D8B); // blue-grey — generic
    }
  }

  /// أيقونات Material الأقرب لرموز Mapbox Maki / POI.
  static IconData iconDataFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.mosque:
        return Icons.mosque_rounded;
      case MapLandmarkType.restaurant:
        return Icons.restaurant_rounded;
      case MapLandmarkType.cafe:
        return Icons.local_cafe_rounded;
      case MapLandmarkType.university:
        return Icons.account_balance_rounded;
      case MapLandmarkType.hospital:
        return Icons.local_hospital_rounded;
      case MapLandmarkType.pharmacy:
        return Icons.local_pharmacy_rounded;
      case MapLandmarkType.school:
        return Icons.school_rounded;
      case MapLandmarkType.shop:
        return Icons.storefront_rounded;
      case MapLandmarkType.supermarket:
        return Icons.local_grocery_store_rounded;
      case MapLandmarkType.park:
        return Icons.park_rounded;
      case MapLandmarkType.government:
        return Icons.account_balance_outlined;
      case MapLandmarkType.bank:
        return Icons.account_balance_wallet_rounded;
      case MapLandmarkType.atm:
        return Icons.atm_rounded;
      case MapLandmarkType.hotel:
        return Icons.hotel_rounded;
      case MapLandmarkType.fuel:
        return Icons.local_gas_station_rounded;
      case MapLandmarkType.parking:
        return Icons.local_parking_rounded;
      case MapLandmarkType.busStation:
        return Icons.directions_bus_rounded;
      case MapLandmarkType.police:
        return Icons.local_police_rounded;
      case MapLandmarkType.postOffice:
        return Icons.local_post_office_rounded;
      case MapLandmarkType.library:
        return Icons.local_library_rounded;
      case MapLandmarkType.museum:
        return Icons.museum_rounded;
      case MapLandmarkType.cinema:
        return Icons.movie_rounded;
      case MapLandmarkType.gym:
        return Icons.fitness_center_rounded;
      case MapLandmarkType.church:
        return Icons.church_rounded;
      case MapLandmarkType.airport:
        return Icons.flight_rounded;
      case MapLandmarkType.carRepair:
        return Icons.car_repair_rounded;
      case MapLandmarkType.other:
        return Icons.place_rounded;
    }
  }

  /// PNG جاهز لـ Mapbox PointAnnotation (مع تخزين مؤقت).
  static Future<Uint8List> bytesFor(MapLandmarkType type) async {
    final hit = _cache[type];
    if (hit != null) return hit;
    final bytes = await _render(type);
    _cache[type] = bytes;
    return bytes;
  }

  /// تحميل مسبق لكل الأنواع (اختياري عند فتح الخريطة).
  static Future<void> preloadAll() async {
    for (final t in MapLandmarkType.values) {
      await bytesFor(t);
    }
  }

  static void clearCache() => _cache.clear();

  static Future<Uint8List> _render(MapLandmarkType type) async {
    const size = markerSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = colorFor(type);

    // ظل خفيف — أسلوب دبوس POI
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 1.5), 28, shadow);

    // حلقة بيضاء خارجية
    final outer = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 28, outer);

    // دائرة ملونة داخلية
    final fill = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), 23, fill);

    final icon = iconDataFor(type);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 26,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2 - 1),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }
}
