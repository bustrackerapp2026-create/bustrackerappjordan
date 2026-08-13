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

  /// نصف قطر لصق النقطة على أقرب شارع (متر)
  static const double pointSnapRadiusM = 55;

  String? get _mapboxToken {
    final t = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (t.isEmpty || t == 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') return null;
    return t;
  }

  Future<String?> _httpGet(Uri uri, {Duration timeout = const Duration(seconds: 14)}) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != HttpStatus.ok) {
        debugPrint('mapbox HTTP ${res.statusCode} → ${uri.path}');
        return null;
      }
      return await res.transform(utf8.decoder).join();
    } catch (e) {
      debugPrint('mapbox HTTP error: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  List<RoutePoint> _parseGeoJsonLine(Map<String, dynamic>? geom) {
    final coordinates = geom?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) return const [];
    final path = <RoutePoint>[];
    for (final c in coordinates) {
      if (c is! List || c.length < 2) continue;
      path.add(RoutePoint(
        latitude: (c[1] as num).toDouble(),
        longitude: (c[0] as num).toDouble(),
      ));
    }
    return path;
  }

  /// لصق نقطة واحدة على أقرب شارع عبر Map Matching (نقطة مزدوجة بزحزحة طفيفة).
  Future<RoutePoint> snapPointToRoad(RoutePoint point) async {
    final token = _mapboxToken;
    if (token == null) return point;

    // زحزحة ~8 أمتار شرقاً لإنشاء أثر قصير يقبله Matching API
    const dLng = 0.00008;
    final p2 = RoutePoint(
      latitude: point.latitude,
      longitude: point.longitude + dLng,
    );

    final coords =
        '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)};'
        '${p2.longitude.toStringAsFixed(6)},${p2.latitude.toStringAsFixed(6)}';

    final uri = Uri.parse(
      'https://api.mapbox.com/matching/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&tidy=true'
      '&radiuses=${pointSnapRadiusM.toStringAsFixed(0)};${pointSnapRadiusM.toStringAsFixed(0)}'
      '&access_token=$token',
    );

    final body = await _httpGet(uri, timeout: const Duration(seconds: 8));
    if (body == null) return point;

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final matchings = data['matchings'] as List<dynamic>?;
      if (matchings == null || matchings.isEmpty) return point;

      final path = _parseGeoJsonLine(
        matchings.first['geometry'] as Map<String, dynamic>?,
      );
      if (path.isEmpty) return point;

      // أقرب نقطة من الأثر إلى النقرة الأصلية
      RoutePoint best = path.first;
      var bestD = double.infinity;
      for (final p in path) {
        final d = _distanceMeters(
          point.latitude,
          point.longitude,
          p.latitude,
          p.longitude,
        );
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
      return best;
    } catch (e) {
      debugPrint('snapPointToRoad: $e');
      return point;
    }
  }

  /// مسار قيادة حقيقي بين نقطتين على الشبكة الطرقية.
  Future<List<RoutePoint>> getDrivingPath({
    required RoutePoint from,
    required RoutePoint to,
    bool snapEndpoints = true,
  }) async {
    final token = _mapboxToken;
    if (token == null) return [from, to];

    var a = from;
    var b = to;
    if (snapEndpoints) {
      final snapped = await Future.wait([
        snapPointToRoad(from),
        snapPointToRoad(to),
      ]);
      a = snapped[0];
      b = snapped[1];
    }

    final dist = _distanceMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    // نقاط متقاربة جداً: لا داعي لطلب Directions
    if (dist < 12) return [a, b];

    final coords =
        '${a.longitude.toStringAsFixed(6)},${a.latitude.toStringAsFixed(6)};'
        '${b.longitude.toStringAsFixed(6)},${b.latitude.toStringAsFixed(6)}';

    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&steps=false'
      '&continue_straight=true&alternatives=false'
      '&access_token=$token',
    );

    final body = await _httpGet(uri);
    if (body == null) return [a, b];

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [a, b];

      final path = _parseGeoJsonLine(
        routes.first['geometry'] as Map<String, dynamic>?,
      );
      if (path.length < 2) return [a, b];

      // تأكد من أن البداية/النهاية تطابق النقاط الملصقة
      return _stitchEndpoints(path, a, b);
    } catch (e) {
      debugPrint('getDrivingPath: $e');
      return [a, b];
    }
  }

  List<RoutePoint> _stitchEndpoints(
    List<RoutePoint> path,
    RoutePoint start,
    RoutePoint end,
  ) {
    final out = <RoutePoint>[start];
    for (final p in path) {
      if (_distanceMeters(
            out.last.latitude,
            out.last.longitude,
            p.latitude,
            p.longitude,
          ) >=
          3) {
        out.add(p);
      }
    }
    if (_distanceMeters(
          out.last.latitude,
          out.last.longitude,
          end.latitude,
          end.longitude,
        ) >
        3) {
      out.add(end);
    } else if (out.isNotEmpty) {
      out[out.length - 1] = end;
    }
    return out;
  }

  /// مسار قيادة عبر عدة نقاط تحكم (حتى 25 نقطة) بعد لصقها على الشارع.
  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints, {
    bool snapWaypoints = true,
  }) async {
    if (waypoints.length < 2) return List.of(waypoints);
    final token = _mapboxToken;
    if (token == null) return List.of(waypoints);

    List<RoutePoint> pts = List.of(waypoints);
    if (snapWaypoints) {
      // لصق متوازٍ لمجموعات صغيرة لتسريع الرسم
      final snapped = <RoutePoint>[];
      for (var i = 0; i < pts.length; i += 6) {
        final chunk = pts.sublist(i, math.min(i + 6, pts.length));
        final done = await Future.wait(chunk.map(snapPointToRoad));
        snapped.addAll(done);
      }
      pts = _dedupeNear(snapped, minMeters: 8);
      if (pts.length < 2) return List.of(waypoints);
    }

    // Mapbox Directions: حد أقصى 25 إحداثية
    final routePts = pts.length <= 25 ? pts : _sampleEvenly(pts, 25);

    // إن كان عدد النقاط كبيراً: اربط قطعاً متتالية ثم ادمج
    if (routePts.length > 12) {
      return _driveInChunks(routePts);
    }

    final coords = routePts
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');

    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&steps=false'
      '&continue_straight=true&alternatives=false'
      '&access_token=$token',
    );

    final body = await _httpGet(uri, timeout: const Duration(seconds: 18));
    if (body == null) {
      return await snapToRoads(waypoints);
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return await snapToRoads(waypoints);
      }
      final path = _parseGeoJsonLine(
        routes.first['geometry'] as Map<String, dynamic>?,
      );
      if (path.length < 2) return await snapToRoads(waypoints);

      // تنعيم نهائي عبر Map Matching على المسار الكثيف
      final polished = await snapToRoads(path, minSpacingMeters: 10);
      return polished.length >= 2
          ? simplifyPoints(polished, minDistanceMeters: 8)
          : simplifyPoints(path, minDistanceMeters: 8);
    } catch (e) {
      debugPrint('getDrivingPathThrough: $e');
      return await snapToRoads(waypoints);
    }
  }

  /// تقسيم المسار الطويل إلى قطع Directions ثم دمجها.
  Future<List<RoutePoint>> _driveInChunks(List<RoutePoint> pts) async {
    final out = <RoutePoint>[];
    const chunkSize = 10; // نقاط تحكم لكل طلب
    for (var i = 0; i < pts.length - 1; i += chunkSize - 1) {
      final end = math.min(i + chunkSize, pts.length);
      final chunk = pts.sublist(i, end);
      if (chunk.length < 2) continue;

      final coords = chunk
          .map((p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
          .join(';');
      final token = _mapboxToken;
      if (token == null) {
        out.addAll(chunk.skip(out.isEmpty ? 0 : 1));
        continue;
      }

      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
        '?geometries=geojson&overview=full&steps=false'
        '&continue_straight=true&alternatives=false'
        '&access_token=$token',
      );

      final body = await _httpGet(uri);
      List<RoutePoint> path = chunk;
      if (body != null) {
        try {
          final data = jsonDecode(body) as Map<String, dynamic>;
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final parsed = _parseGeoJsonLine(
              routes.first['geometry'] as Map<String, dynamic>?,
            );
            if (parsed.length >= 2) path = parsed;
          }
        } catch (_) {}
      }

      if (out.isEmpty) {
        out.addAll(path);
      } else {
        out.addAll(path.skip(1));
      }
    }
    return _dedupeNear(out, minMeters: 5);
  }

  List<RoutePoint> _dedupeNear(List<RoutePoint> input, {double minMeters = 5}) {
    if (input.isEmpty) return const [];
    final out = <RoutePoint>[input.first];
    for (var i = 1; i < input.length; i++) {
      final p = input[i];
      if (_distanceMeters(
            out.last.latitude,
            out.last.longitude,
            p.latitude,
            p.longitude,
          ) >=
          minMeters) {
        out.add(p);
      }
    }
    return out;
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

  /// بناء مسار نهائي عالي الجودة من نقاط تحكم الأدمن.
  Future<List<RoutePoint>> buildRoadAlignedRoute(List<RoutePoint> controlPoints) async {
    if (controlPoints.length < 2) return List.of(controlPoints);

    // 1) لصق نقاط التحكم على الشارع
    // 2) Directions عبرها
    // 3) Map Matching للتنعيم
    final viaDirs = await getDrivingPathThrough(
      controlPoints,
      snapWaypoints: true,
    );
    if (viaDirs.length >= 2) {
      return simplifyPoints(viaDirs, minDistanceMeters: 8);
    }

    final matched = await snapToRoads(
      controlPoints,
      minSpacingMeters: 12,
    );
    return matched.length >= 2
        ? matched
        : simplifyPoints(controlPoints, minDistanceMeters: 10);
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

  Future<List<PlannedRoute>> searchApprovedRoutes(String query) async {
    final q = ArabicSearch.normalize(query);
    if (q.isEmpty) return const [];

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

  Future<List<RoutePoint>> snapToRoads(
    List<RoutePoint> points, {
    double minSpacingMeters = 20,
  }) async {
    final simplified =
        simplifyPoints(points, minDistanceMeters: minSpacingMeters);
    if (simplified.length < 2) return simplified;

    try {
      final token = _mapboxToken;
      if (token == null) return simplified;

      // Map Matching يقبل حتى 100 إحداثية تقريباً
      final sample = simplified.length <= 95
          ? simplified
          : simplifyPoints(simplified, minDistanceMeters: minSpacingMeters * 1.8);

      final coords = sample
          .map((p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
          .join(';');

      final radiuses =
          List.filled(sample.length, pointSnapRadiusM.toStringAsFixed(0))
              .join(';');

      final uri = Uri.parse(
        'https://api.mapbox.com/matching/v5/mapbox/driving/$coords'
        '?geometries=geojson&overview=full&tidy=true'
        '&radiuses=$radiuses'
        '&access_token=$token',
      );

      final body = await _httpGet(uri);
      if (body == null) return simplified;

      final data = jsonDecode(body) as Map<String, dynamic>;
      final matchings = data['matchings'] as List<dynamic>?;
      if (matchings == null || matchings.isEmpty) return simplified;

      // دمج كل أجزاء المطابقة إن وُجدت عدة
      final snapped = <RoutePoint>[];
      for (final m in matchings) {
        if (m is! Map<String, dynamic>) continue;
        final path = _parseGeoJsonLine(m['geometry'] as Map<String, dynamic>?);
        if (path.isEmpty) continue;
        if (snapped.isEmpty) {
          snapped.addAll(path);
        } else {
          snapped.addAll(path.skip(1));
        }
      }

      return snapped.isNotEmpty
          ? simplifyPoints(snapped, minDistanceMeters: 8)
          : simplified;
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

    final points = snap
        ? await buildRoadAlignedRoute(rawPoints)
        : simplifyPoints(rawPoints);
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

    final List<RoutePoint> finalPoints;
    if (alreadySnapped && points.length >= 2) {
      // تنعيم خفيف + matching نهائي
      final polished = await snapToRoads(points, minSpacingMeters: 10);
      finalPoints = polished.length >= 2
          ? simplifyPoints(polished, minDistanceMeters: 8)
          : simplifyPoints(points, minDistanceMeters: 8);
    } else {
      finalPoints = await buildRoadAlignedRoute(points);
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
