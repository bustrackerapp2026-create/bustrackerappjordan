import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/planned_route.dart';
import '../models/route_point.dart';

/// خدمة مسارات الخطوط المخططة (ذهاب/إياب) مع اعتماد الأدمن.
class RoutePlanService {
  RoutePlanService._();
  static final RoutePlanService instance = RoutePlanService._();
  factory RoutePlanService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('plannedRoutes');

  /// أقصى نقطتين مخزّنتين لكل سائق+خط: ذهاب + إياب
  static const int maxDirections = 2;
  static const int minPointsToSave = 8;
  static const int maxPointsToStore = 800;

  Stream<List<PlannedRoute>> watchDriverRoutes(String driverId) {
    return _col
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => PlannedRoute.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) => a.direction.index.compareTo(b.direction.index));
      return list;
    });
  }

  /// مسارات معتمدة لخط معيّن (للعرض على خريطة الركاب)
  Stream<List<PlannedRoute>> watchApprovedRoutesForLine(String lineName) {
    return _col
        .where('lineName', isEqualTo: lineName)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .where((r) => r.points.length >= 2)
            .toList());
  }

  Future<PlannedRoute?> getDriverDirection({
    required String driverId,
    required String lineName,
    required RouteDirection direction,
  }) async {
    final q = await _col
        .where('driverId', isEqualTo: driverId)
        .where('lineName', isEqualTo: lineName)
        .where('direction', isEqualTo: direction.firestoreValue)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return PlannedRoute.fromDoc(q.docs.first.id, q.docs.first.data());
  }

  /// تبسيط النقاط المتقاربة قبل المطابقة/الحفظ
  List<RoutePoint> simplifyPoints(
    List<RoutePoint> input, {
    double minDistanceMeters = 25,
  }) {
    if (input.isEmpty) return const [];
    final out = <RoutePoint>[input.first];
    for (var i = 1; i < input.length; i++) {
      final prev = out.last;
      final cur = input[i];
      if (_distanceMeters(
            prev.latitude,
            prev.longitude,
            cur.latitude,
            cur.longitude,
          ) >=
          minDistanceMeters) {
        out.add(cur);
      }
    }
    if (out.length > 1) {
      final last = input.last;
      final tail = out.last;
      if (_distanceMeters(
            tail.latitude,
            tail.longitude,
            last.latitude,
            last.longitude,
          ) >
          5) {
        out.add(last);
      }
    }
    if (out.length > maxPointsToStore) {
      // عيّنة منتظمة
      final step = out.length / maxPointsToStore;
      final sampled = <RoutePoint>[];
      for (var i = 0; i < maxPointsToStore - 1; i++) {
        sampled.add(out[(i * step).floor()]);
      }
      sampled.add(out.last);
      return sampled;
    }
    return out;
  }

  /// محاولة محاذاة المسار على الشوارع عبر Mapbox Map Matching
  Future<List<RoutePoint>> snapToRoads(List<RoutePoint> points) async {
    final simplified = simplifyPoints(points, minDistanceMeters: 20);
    if (simplified.length < 2) return simplified;

    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      if (token.isEmpty) return simplified;

      // Map Matching يقبل حتى ~100 إحداثية لكل طلب — نأخذ عيّنة
      final sample = simplified.length <= 90
          ? simplified
          : simplifyPoints(simplified, minDistanceMeters: 40);

      final coords = sample
          .map((p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
          .join(';');

      final uri = Uri.parse(
        'https://api.mapbox.com/matching/v5/mapbox/driving/$coords'
        '?geometries=geojson&overview=full&tidy=true&access_token=$token',
      );

      final client = HttpClient();
      try {
        final req = await client.getUrl(uri);
        final res = await req.close().timeout(const Duration(seconds: 12));
        if (res.statusCode != HttpStatus.ok) {
          debugPrint('map matching status: ${res.statusCode}');
          return simplified;
        }
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final matchings = data['matchings'] as List<dynamic>?;
        if (matchings == null || matchings.isEmpty) return simplified;

        final geom = matchings.first['geometry'] as Map<String, dynamic>?;
        final coordinates = geom?['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.isEmpty) return simplified;

        final snapped = <RoutePoint>[];
        for (final c in coordinates) {
          if (c is! List || c.length < 2) continue;
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          snapped.add(RoutePoint(latitude: lat, longitude: lng));
        }
        return snapped.isNotEmpty ? simplifyPoints(snapped, minDistanceMeters: 15) : simplified;
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('snapToRoads: $e');
      return simplified;
    }
  }

  double totalDistanceMeters(List<RoutePoint> points) {
    if (points.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += _distanceMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return sum;
  }

  /// حفظ مسار جديد أو استبدال إن كان مرفوضاً / قيد الانتظار بدون قفل.
  Future<PlannedRoute> saveRecordedRoute({
    required String driverId,
    required String lineName,
    required RouteDirection direction,
    required List<RoutePoint> rawPoints,
  }) async {
    if (driverId.isEmpty) throw ArgumentError('driverId مطلوب');
    if (lineName.trim().isEmpty) throw ArgumentError('اسم الخط مطلوب');

    final existing = await getDriverDirection(
      driverId: driverId,
      lineName: lineName.trim(),
      direction: direction,
    );

    if (existing != null && existing.isLocked) {
      throw StateError(
        'المسار ${direction.labelAr} معتمد ومقفول. '
        'اطلب تعديلًا من الأدمن أولاً.',
      );
    }

    if (existing != null &&
        existing.status == PlannedRouteStatus.approved &&
        existing.editRequestPending) {
      // بعد موافقة الأدمن على طلب التعديل يُسمح بالحفظ كـ pending جديد
    }

    final snapped = await snapToRoads(rawPoints);
    if (snapped.length < minPointsToSave) {
      throw StateError(
        'المسار قصير جداً (${snapped.length} نقطة). '
        'سجّل مسافة أطول قبل الحفظ.',
      );
    }

    final distance = totalDistanceMeters(snapped);
    final payload = <String, dynamic>{
      'driverId': driverId,
      'lineName': lineName.trim(),
      'direction': direction.firestoreValue,
      'points': snapped.map((p) => p.toMap()).toList(),
      'status': PlannedRouteStatus.pending.firestoreValue,
      'editRequestPending': false,
      'distanceMeters': distance,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (existing == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(payload);
      return PlannedRoute(
        id: ref.id,
        driverId: driverId,
        lineName: lineName.trim(),
        direction: direction,
        points: snapped,
        status: PlannedRouteStatus.pending,
        distanceMeters: distance,
      );
    }

    await _col.doc(existing.id).update(payload);
    return PlannedRoute(
      id: existing.id,
      driverId: driverId,
      lineName: lineName.trim(),
      direction: direction,
      points: snapped,
      status: PlannedRouteStatus.pending,
      distanceMeters: distance,
    );
  }

  /// طلب تعديل مسار معتمد — يحتاج موافقة الأدمن قبل إعادة التسجيل
  Future<void> requestEdit({required String routeId}) async {
    await _col.doc(routeId).update({
      'editRequestPending': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRoute(String routeId) async {
    await _col.doc(routeId).update({
      'status': PlannedRouteStatus.approved.firestoreValue,
      'editRequestPending': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRoute(String routeId, {String? reason}) async {
    await _col.doc(routeId).update({
      'status': PlannedRouteStatus.rejected.firestoreValue,
      'editRequestPending': false,
      if (reason != null) 'notes': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// الأدمن يوافق على طلب التعديل فيُفتح القفل مؤقتاً (status يبقى approved مع editRequestPending)
  /// أو نحوّل إلى pending ليُعاد التسجيل
  Future<void> approveEditRequest(String routeId) async {
    await _col.doc(routeId).update({
      'status': PlannedRouteStatus.pending.firestoreValue,
      'editRequestPending': false,
      'points': [],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PlannedRoute>> watchPendingRoutes() {
    return _col
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .toList());
  }

  Stream<List<PlannedRoute>> watchEditRequests() {
    return _col
        .where('editRequestPending', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .toList());
  }

  double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double d) => d * math.pi / 180;
}
