import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/map_landmark.dart';

/// أيقونات معالم المشروع — أسلوب قريب من Google Maps / Mapbox POI.
/// الحجم على الشاشة يتغيّر مع الزوم عبر [iconSizeForZoom].
class LandmarkMarkerImages {
  LandmarkMarkerImages._();

  /// حجم الصورة المولَّدة (px) — دقة كافية للريتينا.
  static const double markerSize = 80;

  /// حجم أساسي عند زوم المدينة (~14) قبل تطبيق منحنى الزوم.
  static const double baseMapIconSize = 0.95;

  /// حجم اسم المعلم تحت الأيقونة عند الزوم المتوسط.
  static const double labelTextSize = 12.0;

  /// يظهر الاسم من هذا الزوم فما فوق (مثل تسميات Google POI).
  static const double labelMinZoom = 13.5;

  static final Map<MapLandmarkType, Uint8List> _cache = {};

  /// حجم الأيقونة على الشاشة حسب زوم الكاميرا — سلوك قريب من Google Maps:
  /// الأيقونة تبقى مقروءة عند الابتعاد، وتكبر قليلاً عند الاقتراب دون تضخم مفرط.
  static double iconSizeForZoom(double zoom) {
    if (zoom <= 11) return 0.55;
    if (zoom <= 12.5) return 0.72;
    if (zoom <= 14) return 0.88;
    if (zoom <= 15.5) return 1.0;
    if (zoom <= 17) return 1.12;
    return 1.22;
  }

  static bool showLabelForZoom(double zoom) => zoom >= labelMinZoom;

  static double textSizeForZoom(double zoom) {
    if (zoom < labelMinZoom) return 0;
    if (zoom < 15) return 11;
    if (zoom < 16.5) return 12;
    return 13;
  }

  /// إزاحة النص تحت الأيقونة (em) — تزداد قليلاً مع كبر الأيقونة.
  static List<double> textOffsetForZoom(double zoom) {
    final y = zoom >= 16 ? 1.25 : (zoom >= 14 ? 1.15 : 1.05);
    return [0.0, y];
  }

  static Color colorFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.restaurant:
        return const Color(0xFFFB8C00);
      case MapLandmarkType.cafe:
        return const Color(0xFFEF6C00);
      case MapLandmarkType.fastFood:
        return const Color(0xFFFF6F00);
      case MapLandmarkType.bakery:
        return const Color(0xFFF57C00);
      case MapLandmarkType.bar:
        return const Color(0xFFE65100);
      case MapLandmarkType.hotel:
        return const Color(0xFF6A1B9A);
      case MapLandmarkType.house:
        return const Color(0xFF5D4037);
      case MapLandmarkType.shop:
        return const Color(0xFF8E24AA);
      case MapLandmarkType.supermarket:
        return const Color(0xFF7B1FA2);
      case MapLandmarkType.clothing:
        return const Color(0xFFAB47BC);
      case MapLandmarkType.convenience:
        return const Color(0xFF9C27B0);
      case MapLandmarkType.market:
        return const Color(0xFF6A1B9A);
      case MapLandmarkType.hospital:
        return const Color(0xFFE53935);
      case MapLandmarkType.medicalCenter:
        return const Color(0xFFC62828);
      case MapLandmarkType.pharmacy:
        return const Color(0xFFD81B60);
      case MapLandmarkType.clinic:
        return const Color(0xFFEC407A);
      case MapLandmarkType.dentist:
        return const Color(0xFFF06292);
      case MapLandmarkType.school:
        return const Color(0xFF1E88E5);
      case MapLandmarkType.university:
        return const Color(0xFF5E35B1);
      case MapLandmarkType.college:
        return const Color(0xFF7E57C2);
      case MapLandmarkType.kindergarten:
        return const Color(0xFF42A5F5);
      case MapLandmarkType.library:
        return const Color(0xFF4527A0);
      case MapLandmarkType.mosque:
        return const Color(0xFF00897B);
      case MapLandmarkType.church:
        return const Color(0xFF5D4037);
      case MapLandmarkType.bank:
        return const Color(0xFF1565C0);
      case MapLandmarkType.atm:
        return const Color(0xFF0277BD);
      case MapLandmarkType.fuel:
        return const Color(0xFFF57C00);
      case MapLandmarkType.chargingStation:
        return const Color(0xFF43A047);
      case MapLandmarkType.parking:
        return const Color(0xFF3949AB);
      case MapLandmarkType.busStation:
        return const Color(0xFF00838F);
      case MapLandmarkType.trainStation:
        return const Color(0xFF00695C);
      case MapLandmarkType.airport:
        return const Color(0xFF37474F);
      case MapLandmarkType.taxi:
        return const Color(0xFFFBC02D);
      case MapLandmarkType.roundabout:
        return const Color(0xFF455A64);
      case MapLandmarkType.trafficLight:
        return const Color(0xFFD32F2F);
      case MapLandmarkType.pedestrianBridge:
        return const Color(0xFF00897B);
      case MapLandmarkType.vehicleBridge:
        return const Color(0xFF546E7A);
      case MapLandmarkType.crosswalk:
        return const Color(0xFF00796B);
      case MapLandmarkType.tunnel:
        return const Color(0xFF37474F);
      case MapLandmarkType.warningTriangle:
        return const Color(0xFFF9A825);
      case MapLandmarkType.government:
        return const Color(0xFF546E7A);
      case MapLandmarkType.police:
        return const Color(0xFF283593);
      case MapLandmarkType.fireStation:
        return const Color(0xFFC62828);
      case MapLandmarkType.postOffice:
        return const Color(0xFF455A64);
      case MapLandmarkType.embassy:
        return const Color(0xFF37474F);
      case MapLandmarkType.park:
        return const Color(0xFF2E7D32);
      case MapLandmarkType.playground:
        return const Color(0xFF66BB6A);
      case MapLandmarkType.museum:
        return const Color(0xFF6D4C41);
      case MapLandmarkType.cinema:
        return const Color(0xFFAD1457);
      case MapLandmarkType.gym:
        return const Color(0xFF00897B);
      case MapLandmarkType.stadium:
        return const Color(0xFF1565C0);
      case MapLandmarkType.beach:
        return const Color(0xFF29B6F6);
      case MapLandmarkType.zoo:
        return const Color(0xFF558B2F);
      case MapLandmarkType.aquarium:
        return const Color(0xFF0288D1);
      case MapLandmarkType.attraction:
        return const Color(0xFF8D6E63);
      case MapLandmarkType.carRepair:
        return const Color(0xFF616161);
      case MapLandmarkType.carRental:
        return const Color(0xFF78909C);
      case MapLandmarkType.laundry:
        return const Color(0xFF26A69A);
      case MapLandmarkType.hairdresser:
        return const Color(0xFFEC407A);
      case MapLandmarkType.barber:
        return const Color(0xFF5D4037);
      case MapLandmarkType.beautySalon:
        return const Color(0xFFE91E63);
      case MapLandmarkType.toilet:
        return const Color(0xFF78909C);
      case MapLandmarkType.other:
        return const Color(0xFF607D8B);
    }
  }

  static IconData iconDataFor(MapLandmarkType type) {
    switch (type) {
      case MapLandmarkType.restaurant:
        return Icons.restaurant_rounded;
      case MapLandmarkType.cafe:
        return Icons.local_cafe_rounded;
      case MapLandmarkType.fastFood:
        return Icons.fastfood_rounded;
      case MapLandmarkType.bakery:
        return Icons.bakery_dining_rounded;
      case MapLandmarkType.bar:
        return Icons.local_bar_rounded;
      case MapLandmarkType.hotel:
        return Icons.hotel_rounded;
      case MapLandmarkType.house:
        return Icons.home_rounded;
      case MapLandmarkType.shop:
        return Icons.storefront_rounded;
      case MapLandmarkType.supermarket:
        return Icons.local_grocery_store_rounded;
      case MapLandmarkType.clothing:
        return Icons.checkroom_rounded;
      case MapLandmarkType.convenience:
        return Icons.store_rounded;
      case MapLandmarkType.market:
        return Icons.store_mall_directory_rounded;
      case MapLandmarkType.hospital:
        return Icons.local_hospital_rounded;
      case MapLandmarkType.medicalCenter:
        return Icons.health_and_safety_rounded;
      case MapLandmarkType.pharmacy:
        return Icons.local_pharmacy_rounded;
      case MapLandmarkType.clinic:
        return Icons.medical_services_rounded;
      case MapLandmarkType.dentist:
        return Icons.medical_services_outlined;
      case MapLandmarkType.school:
        return Icons.school_rounded;
      case MapLandmarkType.university:
        return Icons.account_balance_rounded;
      case MapLandmarkType.college:
        return Icons.school_outlined;
      case MapLandmarkType.kindergarten:
        return Icons.child_care_rounded;
      case MapLandmarkType.library:
        return Icons.local_library_rounded;
      case MapLandmarkType.mosque:
        return Icons.mosque_rounded;
      case MapLandmarkType.church:
        return Icons.church_rounded;
      case MapLandmarkType.bank:
        return Icons.account_balance_wallet_rounded;
      case MapLandmarkType.atm:
        return Icons.atm_rounded;
      case MapLandmarkType.fuel:
        return Icons.local_gas_station_rounded;
      case MapLandmarkType.chargingStation:
        return Icons.ev_station_rounded;
      case MapLandmarkType.parking:
        return Icons.local_parking_rounded;
      case MapLandmarkType.busStation:
        return Icons.directions_bus_rounded;
      case MapLandmarkType.trainStation:
        return Icons.train_rounded;
      case MapLandmarkType.airport:
        return Icons.flight_rounded;
      case MapLandmarkType.taxi:
        return Icons.local_taxi_rounded;
      case MapLandmarkType.roundabout:
        return Icons.roundabout_left_rounded;
      case MapLandmarkType.trafficLight:
        return Icons.traffic_rounded;
      case MapLandmarkType.pedestrianBridge:
        return Icons.directions_walk_rounded;
      case MapLandmarkType.vehicleBridge:
        return Icons.directions_car_filled_rounded;
      case MapLandmarkType.crosswalk:
        return Icons.transfer_within_a_station_rounded;
      case MapLandmarkType.tunnel:
        return Icons.subway_rounded;
      case MapLandmarkType.warningTriangle:
        return Icons.warning_amber_rounded;
      case MapLandmarkType.government:
        return Icons.account_balance_outlined;
      case MapLandmarkType.police:
        return Icons.local_police_rounded;
      case MapLandmarkType.fireStation:
        return Icons.local_fire_department_rounded;
      case MapLandmarkType.postOffice:
        return Icons.local_post_office_rounded;
      case MapLandmarkType.embassy:
        return Icons.flag_rounded;
      case MapLandmarkType.park:
        return Icons.park_rounded;
      case MapLandmarkType.playground:
        return Icons.toys_rounded;
      case MapLandmarkType.museum:
        return Icons.museum_rounded;
      case MapLandmarkType.cinema:
        return Icons.movie_rounded;
      case MapLandmarkType.gym:
        return Icons.fitness_center_rounded;
      case MapLandmarkType.stadium:
        return Icons.stadium_rounded;
      case MapLandmarkType.beach:
        return Icons.beach_access_rounded;
      case MapLandmarkType.zoo:
        return Icons.pets_rounded;
      case MapLandmarkType.aquarium:
        return Icons.water_rounded;
      case MapLandmarkType.attraction:
        return Icons.attractions_rounded;
      case MapLandmarkType.carRepair:
        return Icons.car_repair_rounded;
      case MapLandmarkType.carRental:
        return Icons.directions_car_rounded;
      case MapLandmarkType.laundry:
        return Icons.local_laundry_service_rounded;
      case MapLandmarkType.hairdresser:
        return Icons.content_cut_rounded;
      case MapLandmarkType.barber:
        return Icons.face_retouching_natural_rounded;
      case MapLandmarkType.beautySalon:
        return Icons.spa_rounded;
      case MapLandmarkType.toilet:
        return Icons.wc_rounded;
      case MapLandmarkType.other:
        return Icons.place_rounded;
    }
  }

  static Future<Uint8List> bytesFor(MapLandmarkType type) async {
    final hit = _cache[type];
    if (hit != null) return hit;
    final bytes = await _render(type);
    _cache[type] = bytes;
    return bytes;
  }

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

    // دائرة أوضح — حجم شاشة أقرب لـ Google POI (~28–32px عند scale 1)
    const radius = 22.0;
    const inner = 18.0;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 1.2), radius, shadow);

    final outer = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), radius, outer);

    final fill = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), inner, fill);

    final icon = iconDataFor(type);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
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
}
