import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/utils/arabic_search.dart';
import '../models/planned_route.dart';
import '../models/route_point.dart';

/// خدمة مسارات الخطوط المشتركة (ذهاب/إياب).
/// المسار يُخزَّن مرة واحدة لكل (اسم خط + اتجاه) ويُعتمد تلقائياً.
class RoutePlanService {
  RoutePlanService._();
  static final RoutePlanService instance = RoutePlanService._();
  factory RoutePlanService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('plannedRoutes');

  static const int minPointsToSave = 8;
  static const int maxPointsToStore = 800;

  String? get _mapboxToken {
    final t = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (t.isEmpty || t == 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') return null;
    return t;
  }

  /// مسار قيادة حقيقي بين نقطتين (شوارع / جسور / منعطفات) عبر Mapbox Directions.
  Future<List<RoutePoint>> getDrivingPath({
    required RoutePoint from,
    required RoutePoint to,
  }) async {
    final token = _mapboxToken;
    if (token == null) return [from, to];

    final coords =
        '${from.longitude.toStringAsFixed(6)},${from.latitude.toStringAsFixed(6)};'
        '${to.longitude.toStringAsFixed(6)},${to.latitude.toStringAsFixed(6)}';

    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&steps=false&access_token=$token',
    );

    try {
      final client = HttpClient();
      try {
        final req = await client.getUrl(uri);
        final res = await req.close().timeout(const Duration(seconds: 12));
        if (res.statusCode != HttpStatus.ok) {
          debugPrint('directions status: ${res.statusCode}');
          return [from, to];
        }
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes == null || routes.isEmpty) return [from, to];

        final geom = routes.first['geometry'] as Map<String, dynamic>?;
        final coordinates = geom?['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.isEmpty) return [from, to];

        final path = <RoutePoint>[];
        for (final c in coordinates) {
          if (c is! List || c.length < 2) continue;
          path.add(RoutePoint(
            latitude: (c[1] as num).toDouble(),
            longitude: (c[0] as num).toDouble(),
          ));
        }
        return path.length >= 2 ? path : [from, to];
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('getDrivingPath: $e');
      return [from, to];
    }
  }

  /// مسار قيادة عبر عدة نقاط تحكم (حتى 25 نقطة).
  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints,
  ) async {
    if (waypoints.length < 2) return List.of(waypoints);
    final token = _mapboxToken;
    if (token == null) return List.of(waypoints);

    // Mapbox Directions: حد أقصى 25 إحداثية
    final pts = waypoints.length <= 25
        ? waypoints
        : _sampleEvenly(waypoints, 25);

    final coords = pts
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');

    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&steps=false&access_token=$token',
    );

    try {
      final client = HttpClient();
      try {
        final req = await client.getUrl(uri);
        final res = await req.close().timeout(const Duration(seconds: 15));
        if (res.statusCode != HttpStatus.ok) {
          debugPrint('directions multi status: ${res.statusCode}');
          return await snapToRoads(waypoints);
        }
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes == null || routes.isEmpty) {
          return await snapToRoads(waypoints);
        }
        final geom = routes.first['geometry'] as Map<String, dynamic>?;
        final coordinates = geom?['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.isEmpty) {
          return await snapToRoads(waypoints);
        }
        final path = <RoutePoint>[];
        for (final c in coordinates) {
          if (c is! List || c.length < 2) continue;
          path.add(RoutePoint(
            latitude: (c[1] as num).toDouble(),
            longitude: (c[0] as num).toDouble(),
          ));
        }
        return path.length >= 2
            ? simplifyPoints(path, minDistanceMeters: 12)
            : await snapToRoads(waypoints);
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('getDrivingPathThrough: $e');
      return await snapToRoads(waypoints);
    }
  }

  List<RoutePoint> _sampleEvenly(List<RoutePoint> input, int maxCount) {
    if (input.length <= maxCount) return input;
    final out = <RoutePoint>[];
    final step = (input.length - 1) / (maxCount - 1);
    for (var i = 0; i < maxCount; i++) {
      out.add(input[(i * step).round()]);
    }
    return out;
  }

  Stream<List<PlannedRoute>> watchLineRoutes(String lineName) {
    return _col.where('lineName', isEqualTo: lineName).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => PlannedRoute.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) => a.direction.index.compareTo(b.direction.index));
      return list;
    });
  }

  Stream<List<PlannedRoute>> watchDriverRoutes(String driverId) {
    return _col.where('createdBy', isEqualTo: driverId).snapshots().map((snap) {
      return snap.docs
          .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
          .toList();
    });
  }

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

  /// بحث ذكي في المسارات المعتمدة (بالاسم أو مفاتيح البحث).
  Future<List<PlannedRoute>> searchApprovedRoutes(String query) async {
    final q = ArabicSearch.normalize(query);
    if (q.isEmpty) return const [];

    // جلب المعتمدة ثم تصفية محلياً (مفاتيح البحث مصفوفة — لا يناسب where بسهولة)
    final snap = await _col.where('status', isEqualTo: 'approved').get();
    final results = <PlannedRoute>[];
    for (final d in snap.docs) {
      final r = PlannedRoute.fromDoc(d.id, d.data());
      if (r.points.length < 2) continue;
      if (ArabicSearch.matches(
        query: query,
        lineName: r.lineName,
        searchKeys: r.searchKeys,
        aliases: r.aliases,
      )) {
        results.add(r);
      }
    }
    results.sort((a, b) => a.lineName.compareTo(b.lineName));
    return results;
  }

  /// أسماء خطوط فريدة معتمدة (للقوائم والبحث).
  Future<List<String>> listApprovedLineNames() async {
    final snap = await _col.where('status', isEqualTo: 'approved').get();
    final names = <String>{};
    for (final d in snap.docs) {
      final n = d.data()['lineName']?.toString().trim() ?? '';
      if (n.isNotEmpty) names.add(n);
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<PlannedRoute?> getLineDirection({
    required String lineName,
    required RouteDirection direction,
  }) async {
    final q = await _col
        .where('lineName', isEqualTo: lineName.trim())
        .where('direction', isEqualTo: direction.firestoreValue)
        .limit(5)
        .get();
    if (q.docs.isEmpty) return null;

    PlannedRoute? approved;
    PlannedRoute? any;
    for (final d in q.docs) {
      final r = PlannedRoute.fromDoc(d.id, d.data());
      any ??= r;
      if (r.status == PlannedRouteStatus.approved && r.points.length >= 2) {
        approved = r;
        break;
      }
    }
    return approved ?? any;
  }

  @Deprecated('استخدم getLineDirection — المسارات مشتركة باسم الخط')
  Future<PlannedRoute?> getDriverDirection({
    required String driverId,
    required String lineName,
    required RouteDirection direction,
  }) =>
      getLineDirection(lineName: lineName, direction: direction);

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

  Future<List<RoutePoint>> snapToRoads(List<RoutePoint> points) async {
    final simplified = simplifyPoints(points, minDistanceMeters: 20);
    if (simplified.length < 2) return simplified;

    try {
      final token = _mapboxToken;
      if (token == null) return simplified;

      final sample = simplified.length <= 90
          ? simplified
          : simplifyPoints(simplified, minDistanceMeters: 40);

      final coords = sample
          .map((p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
          .join(';');

      // radiuses تساعد على لصق النقاط على أقرب شارع
      final radiuses = List.filled(sample.length, '40').join(';');

      final uri = Uri.parse(
        'https://api.mapbox.com/matching/v5/mapbox/driving/$coords'
        '?geometries=geojson&overview=full&tidy=true'
        '&radiuses=$radiuses'
        '&access_token=$token',
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
        return snapped.isNotEmpty
            ? simplifyPoints(snapped, minDistanceMeters: 12)
            : simplified;
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

  Map<String, dynamic> _searchPayload(String lineName, List<String> aliases) {
    final keys = ArabicSearch.buildSearchKeys(lineName, aliases: aliases);
    return {
      'lineNameNormalized': ArabicSearch.normalize(lineName),
      'searchKeys': keys,
      'aliases': aliases
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
    };
  }

  Future<PlannedRoute> saveRecordedRoute({
    required String driverId,
    required String lineName,
    required RouteDirection direction,
    required List<RoutePoint> rawPoints,
    bool snap = true,
    List<String> aliases = const [],
  }) async {
    if (driverId.isEmpty) throw ArgumentError('driverId مطلوب');
    if (lineName.trim().isEmpty) throw ArgumentError('اسم الخط مطلوب');

    final existing = await getLineDirection(
      lineName: lineName.trim(),
      direction: direction,
    );

    if (existing != null && existing.isLocked) {
      throw StateError(
        'مسار ${direction.labelAr} لخط «${lineName.trim()}» مخزّن مسبقاً. '
        'لا حاجة لتسجيله من جديد. لطلب تعديل اكتب السبب وانتظر موافقة الأدمن.',
      );
    }

    final points =
        snap ? await snapToRoads(rawPoints) : simplifyPoints(rawPoints);
    if (points.length < minPointsToSave) {
      throw StateError(
        'المسار قصير جداً (${points.length} نقطة). '
        'سجّل مسافة أطول قبل الحفظ.',
      );
    }

    final distance = totalDistanceMeters(points);
    final search = _searchPayload(lineName.trim(), aliases);
    final payload = <String, dynamic>{
      'createdBy': driverId,
      'driverId': driverId,
      'lineName': lineName.trim(),
      'direction': direction.firestoreValue,
      'points': points.map((p) => p.toMap()).toList(),
      'status': PlannedRouteStatus.approved.firestoreValue,
      'editRequestPending': false,
      'editRequestReason': FieldValue.delete(),
      'editRequestedBy': FieldValue.delete(),
      'reRecordAllowed': false,
      'distanceMeters': distance,
      'source': RouteSource.driver.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      ...search,
    };

    if (existing == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(payload);
      return PlannedRoute(
        id: ref.id,
        createdBy: driverId,
        lineName: lineName.trim(),
        direction: direction,
        points: points,
        status: PlannedRouteStatus.approved,
        distanceMeters: distance,
        source: RouteSource.driver,
        searchKeys: List<String>.from(search['searchKeys'] as List),
        aliases: List<String>.from(search['aliases'] as List),
      );
    }

    await _col.doc(existing.id).update(payload);
    return PlannedRoute(
      id: existing.id,
      createdBy: driverId,
      lineName: lineName.trim(),
      direction: direction,
      points: points,
      status: PlannedRouteStatus.approved,
      distanceMeters: distance,
      source: RouteSource.driver,
      searchKeys: List<String>.from(search['searchKeys'] as List),
      aliases: List<String>.from(search['aliases'] as List),
    );
  }

  /// الأدمن يحفظ مساراً مرسوماً (معتمد فوراً للكل على Firebase).
  Future<PlannedRoute> saveAdminDrawnRoute({
    required String adminId,
    required String lineName,
    required RouteDirection direction,
    required List<RoutePoint> points,
    bool replaceExisting = true,
    List<String> aliases = const [],
    /// إن كانت النقاط ملصقة بالشارع مسبقاً أثناء الرسم
    bool alreadySnapped = false,
  }) async {
    if (adminId.isEmpty) throw ArgumentError('adminId مطلوب');
    if (lineName.trim().isEmpty) throw ArgumentError('اسم الخط مطلوب');

    final existing = await getLineDirection(
      lineName: lineName.trim(),
      direction: direction,
    );

    if (existing != null && !replaceExisting) {
      throw StateError('المسار موجود مسبقاً لهذا الخط والاتجاه');
    }

    List<RoutePoint> finalPoints;
    if (alreadySnapped && points.length >= 2) {
      finalPoints = simplifyPoints(points, minDistanceMeters: 12);
    } else {
      // إعادة بناء كاملة على الشوارع عبر Directions ثم Matching احتياطي
      final viaDirs = await getDrivingPathThrough(points);
      finalPoints = viaDirs.length >= 2
          ? viaDirs
          : await snapToRoads(simplifyPoints(points, minDistanceMeters: 15));
    }

    if (finalPoints.length < 2) {
      throw StateError('أضف نقطتين على الأقل على الخريطة');
    }

    final distance = totalDistanceMeters(finalPoints);
    final search = _searchPayload(lineName.trim(), aliases);

    final payload = <String, dynamic>{
      'createdBy': adminId,
      'driverId': adminId,
      'lineName': lineName.trim(),
      'direction': direction.firestoreValue,
      'points': finalPoints.map((p) => p.toMap()).toList(),
      'status': PlannedRouteStatus.approved.firestoreValue,
      'editRequestPending': false,
      'reRecordAllowed': false,
      'distanceMeters': distance,
      'source': RouteSource.admin.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      ...search,
    };

    if (existing == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(payload);
      return PlannedRoute(
        id: ref.id,
        createdBy: adminId,
        lineName: lineName.trim(),
        direction: direction,
        points: finalPoints,
        status: PlannedRouteStatus.approved,
        distanceMeters: distance,
        source: RouteSource.admin,
        searchKeys: List<String>.from(search['searchKeys'] as List),
        aliases: List<String>.from(search['aliases'] as List),
      );
    }

    await _col.doc(existing.id).update(payload);
    return PlannedRoute(
      id: existing.id,
      createdBy: adminId,
      lineName: lineName.trim(),
      direction: direction,
      points: finalPoints,
      status: PlannedRouteStatus.approved,
      distanceMeters: distance,
      source: RouteSource.admin,
      searchKeys: List<String>.from(search['searchKeys'] as List),
      aliases: List<String>.from(search['aliases'] as List),
    );
  }

  Future<void> requestEdit({
    required String routeId,
    required String reason,
    required String requestedBy,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) {
      throw ArgumentError('يجب كتابة سبب طلب التعديل');
    }
    await _col.doc(routeId).update({
      'editRequestPending': true,
      'editRequestReason': r,
      'editRequestedBy': requestedBy,
      'reRecordAllowed': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRoute(String routeId) async {
    await _col.doc(routeId).update({
      'status': PlannedRouteStatus.approved.firestoreValue,
      'editRequestPending': false,
      'reRecordAllowed': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRoute(String routeId, {String? reason}) async {
    await _col.doc(routeId).update({
      'status': PlannedRouteStatus.rejected.firestoreValue,
      'editRequestPending': false,
      'reRecordAllowed': false,
      if (reason != null) 'notes': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveEditRequest(String routeId) async {
    await _col.doc(routeId).update({
      'editRequestPending': false,
      'reRecordAllowed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> denyEditRequest(String routeId) async {
    await _col.doc(routeId).update({
      'editRequestPending': false,
      'reRecordAllowed': false,
      'editRequestReason': FieldValue.delete(),
      'editRequestedBy': FieldValue.delete(),
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

  Stream<List<PlannedRoute>> watchAllApprovedRoutes() {
    return _col
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .where((r) => r.points.length >= 2)
            .toList());
  }

  Future<void> deleteRoute(String routeId) async {
    await _col.doc(routeId).delete();
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
