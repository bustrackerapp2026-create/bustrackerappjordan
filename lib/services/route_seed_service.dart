import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// خدمة زرع مسارات تجريبية واقعية بين محافظات الأردن في Firestore.
class RouteSeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> seedJordanDemoRoutes({bool forceOverwrite = true}) async {
    final now = Timestamp.now();
    int routesCount = 0;
    int stopsCount = 0;
    int chunksCount = 0;

    for (final def in _demoRoutes) {
      final routeRef = _db.collection('routes').doc(def.id);

      await routeRef.set({
        'name': def.name,
        'startCity': def.startCity,
        'endCity': def.endCity,
        'vehicleType': def.vehicleType,
        'routeColor': def.routeColor,
        'distanceKm': def.distanceKm,
        'estimatedDuration': def.estimatedDurationMin,
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
        'isDemo': true,
      }, SetOptions(merge: !forceOverwrite));
      routesCount++;

      if (forceOverwrite) {
        final existingStops = await routeRef.collection('stops').get();
        for (final d in existingStops.docs) {
          await d.reference.delete();
        }
      }

      for (var i = 0; i < def.stops.length; i++) {
        final s = def.stops[i];
        await routeRef.collection('stops').doc('stop_${i + 1}').set({
          'routeId': def.id,
          'name': s.name,
          'location': GeoPoint(s.lat, s.lng),
          'order': i + 1,
          'isMajor': s.isMajor,
        });
        stopsCount++;
      }

      if (forceOverwrite) {
        final oldChunks = await _db
            .collection('routeCoordinates')
            .where('routeId', isEqualTo: def.id)
            .get();
        for (final d in oldChunks.docs) {
          await d.reference.delete();
        }
      }

      final points = def.polyline;
      const chunkSize = 40;
      var chunkIndex = 0;
      for (var i = 0; i < points.length; i += chunkSize) {
        final end =
            (i + chunkSize < points.length) ? i + chunkSize : points.length;
        final slice = points.sublist(i, end);
        final coords = slice.map((p) => GeoPoint(p.lat, p.lng)).toList();

        await _db
            .collection('routeCoordinates')
            .doc('${def.id}_c$chunkIndex')
            .set({
          'routeId': def.id,
          'chunkIndex': chunkIndex,
          'coordinates': coords,
        });
        chunkIndex++;
        chunksCount++;
      }

      if (kDebugMode) {
        debugPrint('✅ [RouteSeed] ${def.name}: ${points.length} نقطة');
      }
    }

    return 'تم زرع $routesCount مسارات، $stopsCount محطة، $chunksCount أجزاء إحداثيات.';
  }

  Future<String> clearDemoRoutes() async {
    final snap = await _db
        .collection('routes')
        .where('isDemo', isEqualTo: true)
        .get();

    int deleted = 0;
    for (final doc in snap.docs) {
      final id = doc.id;

      final stops = await doc.reference.collection('stops').get();
      for (final s in stops.docs) {
        await s.reference.delete();
      }

      final chunks = await _db
          .collection('routeCoordinates')
          .where('routeId', isEqualTo: id)
          .get();
      for (final c in chunks.docs) {
        await c.reference.delete();
      }

      await doc.reference.delete();
      deleted++;
    }

    return 'تم حذف $deleted مسار تجريبي.';
  }
}

class _StopDef {
  final String name;
  final double lat;
  final double lng;
  final bool isMajor;
  const _StopDef(this.name, this.lat, this.lng, {this.isMajor = false});
}

class _Point {
  final double lat;
  final double lng;
  const _Point(this.lat, this.lng);
}

class _RouteDef {
  final String id;
  final String name;
  final String startCity;
  final String endCity;
  final String vehicleType;
  final String routeColor;
  final double distanceKm;
  final int estimatedDurationMin;
  final List<_StopDef> stops;
  final List<_Point> polyline;

  const _RouteDef({
    required this.id,
    required this.name,
    required this.startCity,
    required this.endCity,
    required this.vehicleType,
    required this.routeColor,
    required this.distanceKm,
    required this.estimatedDurationMin,
    required this.stops,
    required this.polyline,
  });
}

const List<_RouteDef> _demoRoutes = [
  _RouteDef(
    id: 'route_amman_irbid',
    name: 'خط عمان — إربد',
    startCity: 'عمّان',
    endCity: 'إربد',
    vehicleType: 'bus',
    routeColor: '#1565C0',
    distanceKm: 88,
    estimatedDurationMin: 90,
    stops: [
      _StopDef('مجمع الشمال — عمّان', 32.0120, 35.8720, isMajor: true),
      _StopDef('الجبيهة', 32.0255, 35.8650),
      _StopDef('صويلح', 32.0350, 35.8450),
      _StopDef('البقعة', 32.0750, 35.8400),
      _StopDef('جرش (مفترق)', 32.2700, 35.8900),
      _StopDef('مجمع إربد الجديد', 32.5450, 35.8500, isMajor: true),
    ],
    polyline: [
      _Point(32.0120, 35.8720),
      _Point(32.0200, 35.8680),
      _Point(32.0280, 35.8600),
      _Point(32.0400, 35.8480),
      _Point(32.0550, 35.8420),
      _Point(32.0800, 35.8380),
      _Point(32.1100, 35.8450),
      _Point(32.1500, 35.8600),
      _Point(32.1900, 35.8750),
      _Point(32.2300, 35.8850),
      _Point(32.2700, 35.8900),
      _Point(32.3100, 35.8800),
      _Point(32.3600, 35.8700),
      _Point(32.4100, 35.8600),
      _Point(32.4600, 35.8550),
      _Point(32.5000, 35.8500),
      _Point(32.5300, 35.8500),
      _Point(32.5450, 35.8500),
    ],
  ),
  _RouteDef(
    id: 'route_amman_aqaba',
    name: 'خط عمان — العقبة (صحراوي)',
    startCity: 'عمّان',
    endCity: 'العقبة',
    vehicleType: 'bus',
    routeColor: '#C62828',
    distanceKm: 330,
    estimatedDurationMin: 240,
    stops: [
      _StopDef('مجمع الجنوب — عمّان', 31.9000, 35.9100, isMajor: true),
      _StopDef('القسطل', 31.8000, 35.9200),
      _StopDef('الجيزة', 31.7000, 35.9500),
      _StopDef('القطرانة', 31.2500, 36.0500),
      _StopDef('معان', 30.1960, 35.7340, isMajor: true),
      _StopDef('وادي رم (مفترق)', 29.8000, 35.3000),
      _StopDef('مجمع العقبة', 29.5320, 35.0060, isMajor: true),
    ],
    polyline: [
      _Point(31.9000, 35.9100),
      _Point(31.8500, 35.9150),
      _Point(31.8000, 35.9200),
      _Point(31.7500, 35.9350),
      _Point(31.7000, 35.9500),
      _Point(31.6000, 36.0000),
      _Point(31.5000, 36.0300),
      _Point(31.4000, 36.0400),
      _Point(31.3000, 36.0500),
      _Point(31.2500, 36.0500),
      _Point(31.1000, 36.0200),
      _Point(30.9000, 35.9500),
      _Point(30.7000, 35.8800),
      _Point(30.5000, 35.8200),
      _Point(30.3000, 35.7800),
      _Point(30.1960, 35.7340),
      _Point(30.0500, 35.6000),
      _Point(29.9000, 35.4500),
      _Point(29.8000, 35.3000),
      _Point(29.7000, 35.1500),
      _Point(29.6000, 35.0500),
      _Point(29.5320, 35.0060),
    ],
  ),
  _RouteDef(
    id: 'route_amman_zarqa',
    name: 'خط عمان — الزرقاء',
    startCity: 'عمّان',
    endCity: 'الزرقاء',
    vehicleType: 'bus',
    routeColor: '#2E7D32',
    distanceKm: 28,
    estimatedDurationMin: 40,
    stops: [
      _StopDef('مجمع الشمال — عمّان', 32.0120, 35.8720, isMajor: true),
      _StopDef('ماركا', 31.9800, 35.9800),
      _StopDef('الرصيفة', 32.0200, 36.0300),
      _StopDef('مجمع الزرقاء', 32.0720, 36.0880, isMajor: true),
    ],
    polyline: [
      _Point(32.0120, 35.8720),
      _Point(32.0000, 35.9000),
      _Point(31.9900, 35.9400),
      _Point(31.9800, 35.9800),
      _Point(31.9900, 36.0000),
      _Point(32.0000, 36.0200),
      _Point(32.0200, 36.0300),
      _Point(32.0400, 36.0500),
      _Point(32.0550, 36.0700),
      _Point(32.0720, 36.0880),
    ],
  ),
  _RouteDef(
    id: 'route_amman_karak',
    name: 'خط عمان — الكرك',
    startCity: 'عمّان',
    endCity: 'الكرك',
    vehicleType: 'bus',
    routeColor: '#6A1B9A',
    distanceKm: 95,
    estimatedDurationMin: 100,
    stops: [
      _StopDef('مجمع الجنوب — عمّان', 31.9000, 35.9100, isMajor: true),
      _StopDef('ناعور', 31.8700, 35.8200),
      _StopDef('مادبا', 31.7160, 35.7940, isMajor: true),
      _StopDef('ذيبان', 31.5000, 35.7800),
      _StopDef('مجمع الكرك', 31.1850, 35.7050, isMajor: true),
    ],
    polyline: [
      _Point(31.9000, 35.9100),
      _Point(31.8800, 35.8600),
      _Point(31.8700, 35.8200),
      _Point(31.8200, 35.8000),
      _Point(31.7600, 35.7950),
      _Point(31.7160, 35.7940),
      _Point(31.6500, 35.7900),
      _Point(31.5800, 35.7850),
      _Point(31.5000, 35.7800),
      _Point(31.4000, 35.7600),
      _Point(31.3000, 35.7400),
      _Point(31.2200, 35.7200),
      _Point(31.1850, 35.7050),
    ],
  ),
  _RouteDef(
    id: 'route_amman_jerash',
    name: 'خط عمان — جرش',
    startCity: 'عمّان',
    endCity: 'جرش',
    vehicleType: 'bus',
    routeColor: '#EF6C00',
    distanceKm: 48,
    estimatedDurationMin: 55,
    stops: [
      _StopDef('مجمع الشمال — عمّان', 32.0120, 35.8720, isMajor: true),
      _StopDef('صويلح', 32.0350, 35.8450),
      _StopDef('عين الباشا', 32.1000, 35.8500),
      _StopDef('ساكب', 32.2000, 35.8800),
      _StopDef('وسط جرش', 32.2800, 35.8950, isMajor: true),
    ],
    polyline: [
      _Point(32.0120, 35.8720),
      _Point(32.0250, 35.8600),
      _Point(32.0350, 35.8450),
      _Point(32.0600, 35.8480),
      _Point(32.1000, 35.8500),
      _Point(32.1400, 35.8600),
      _Point(32.1800, 35.8700),
      _Point(32.2000, 35.8800),
      _Point(32.2400, 35.8900),
      _Point(32.2800, 35.8950),
    ],
  ),
  _RouteDef(
    id: 'route_zarqa_mafraq',
    name: 'خط الزرقاء — المفرق',
    startCity: 'الزرقاء',
    endCity: 'المفرق',
    vehicleType: 'bus',
    routeColor: '#00838F',
    distanceKm: 45,
    estimatedDurationMin: 50,
    stops: [
      _StopDef('مجمع الزرقاء', 32.0720, 36.0880, isMajor: true),
      _StopDef('الضليل', 32.1500, 36.1500),
      _StopDef('مجمع المفرق', 32.3430, 36.2080, isMajor: true),
    ],
    polyline: [
      _Point(32.0720, 36.0880),
      _Point(32.0900, 36.1000),
      _Point(32.1100, 36.1200),
      _Point(32.1300, 36.1400),
      _Point(32.1500, 36.1500),
      _Point(32.2000, 36.1700),
      _Point(32.2500, 36.1900),
      _Point(32.3000, 36.2000),
      _Point(32.3430, 36.2080),
    ],
  ),
  _RouteDef(
    id: 'route_irbid_mafraq',
    name: 'خط إربد — المفرق',
    startCity: 'إربد',
    endCity: 'المفرق',
    vehicleType: 'bus',
    routeColor: '#4527A0',
    distanceKm: 42,
    estimatedDurationMin: 45,
    stops: [
      _StopDef('مجمع إربد الجديد', 32.5450, 35.8500, isMajor: true),
      _StopDef('الحصن', 32.4800, 35.9000),
      _StopDef('الرمثا (مفترق)', 32.5600, 36.0000),
      _StopDef('مجمع المفرق', 32.3430, 36.2080, isMajor: true),
    ],
    polyline: [
      _Point(32.5450, 35.8500),
      _Point(32.5200, 35.8700),
      _Point(32.5000, 35.8900),
      _Point(32.4800, 35.9000),
      _Point(32.4800, 35.9500),
      _Point(32.5000, 36.0000),
      _Point(32.4800, 36.0500),
      _Point(32.4500, 36.1000),
      _Point(32.4000, 36.1500),
      _Point(32.3600, 36.1800),
      _Point(32.3430, 36.2080),
    ],
  ),
  _RouteDef(
    id: 'route_amman_madaba',
    name: 'خط عمان — مادبا',
    startCity: 'عمّان',
    endCity: 'مادبا',
    vehicleType: 'bus',
    routeColor: '#AD1457',
    distanceKm: 35,
    estimatedDurationMin: 40,
    stops: [
      _StopDef('مجمع الجنوب — عمّان', 31.9000, 35.9100, isMajor: true),
      _StopDef('خريبة السوق', 31.8800, 35.8800),
      _StopDef('ناعور', 31.8700, 35.8200),
      _StopDef('وسط مادبا', 31.7160, 35.7940, isMajor: true),
    ],
    polyline: [
      _Point(31.9000, 35.9100),
      _Point(31.8900, 35.8950),
      _Point(31.8800, 35.8800),
      _Point(31.8750, 35.8500),
      _Point(31.8700, 35.8200),
      _Point(31.8300, 35.8100),
      _Point(31.7800, 35.8000),
      _Point(31.7500, 35.7950),
      _Point(31.7160, 35.7940),
    ],
  ),
];
