import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/route_point.dart';
import 'route_plan_geometry.dart';

/// طلبات Mapbox Matching / Directions — لصق محسّن على شبكة الطرق.
///
/// الاستراتيجية:
/// 1) تنعيم نقاط التحكم بالمسافة
/// 2) لصق كل نقطة على أقرب شارع (Matching ضيق)
/// 3) Directions عبر نوافذ متداخلة (waypoints)
/// 4) Matching نهائي على النوافذ لتنعيم الشكل
/// 5) إزالة القفزات + Douglas-Peucker
class RoutePlanMapbox {
  RoutePlanMapbox._();
  static final RoutePlanMapbox instance = RoutePlanMapbox._();

  /// نصف قطر لصق النقطة على أقرب شارع (متر) — أضيق = أقل قفز فوق مباني
  static const double pointSnapRadiusM = 40;

  /// نصف قطر أوسع عند فشل اللصق الضيق
  static const double pointSnapRadiusWideM = 75;

  /// حد نقاط Map Matching في الطلب الواحد (Mapbox ≤ 100)
  static const int _matchWindow = 48;

  /// حد نقاط Directions في الطلب الواحد (عملياً أفضل ≤ 12)
  static const int _directionsWindow = 10;

  String? get _mapboxToken {
    final t = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (t.isEmpty || t == 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') return null;
    return t;
  }

  Future<String?> _httpGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 16),
  }) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != HttpStatus.ok) {
        if (kDebugMode) {
          debugPrint('mapbox HTTP ${res.statusCode} → ${uri.path}');
        }
        return null;
      }
      return await res.transform(utf8.decoder).join();
    } catch (e) {
      if (kDebugMode) debugPrint('mapbox HTTP error: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  String _coord(RoutePoint p) =>
      '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}';

  /// لصق نقطة واحدة على أقرب طريق قيادة.
  Future<RoutePoint> snapPointToRoad(RoutePoint point) async {
    final token = _mapboxToken;
    if (token == null) return point;

    // محاولة ضيقة ثم أوسع
    for (final radius in [pointSnapRadiusM, pointSnapRadiusWideM]) {
      final snapped = await _matchSinglePoint(point, token, radius);
      if (snapped != null) {
        final d = RoutePlanGeometry.distanceMeters(
          point.latitude,
          point.longitude,
          snapped.latitude,
          snapped.longitude,
        );
        // ارفض إزاحة غير منطقية
        if (d <= radius * 1.15) return snapped;
      }
    }
    return point;
  }

  Future<RoutePoint?> _matchSinglePoint(
    RoutePoint point,
    String token,
    double radiusM,
  ) async {
    // Map Matching يحتاج ≥ 2 إحداثيات — نستخدم إزاحة صغيرة جداً على نفس الشارع المتوقع
    const dLng = 0.000045; // ~4.5م
    final p2 = RoutePoint(
      latitude: point.latitude,
      longitude: point.longitude + dLng,
    );
    final coords = '${_coord(point)};${_coord(p2)}';
    final r = radiusM.toStringAsFixed(0);

    final uri = Uri.parse(
      'https://api.mapbox.com/matching/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&tidy=true'
      '&radiuses=$r;$r'
      '&gaps=ignore'
      '&access_token=$token',
    );

    final body = await _httpGet(uri, timeout: const Duration(seconds: 8));
    if (body == null) return null;

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final matchings = data['matchings'] as List<dynamic>?;
      if (matchings == null || matchings.isEmpty) return null;

      final path = RoutePlanGeometry.parseGeoJsonLine(
        matchings.first['geometry'] as Map<String, dynamic>?,
      );
      if (path.isEmpty) return null;

      // أقرب نقطة على الهندسة المُطابقة
      RoutePoint best = path.first;
      var bestD = double.infinity;
      for (final p in path) {
        final d = RoutePlanGeometry.distanceMeters(
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
      if (kDebugMode) debugPrint('snapPointToRoad: $e');
      return null;
    }
  }

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

    final dist = RoutePlanGeometry.distanceMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (dist < 10) return [a, b];

    final path = await _directionsRequest([a, b], token);
    if (path.length < 2) return [a, b];
    return RoutePlanGeometry.stitchEndpoints(path, a, b);
  }

  Future<List<RoutePoint>> _directionsRequest(
    List<RoutePoint> pts,
    String token,
  ) async {
    if (pts.length < 2) return List.of(pts);

    final coords = pts.map(_coord).join(';');
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&steps=false'
      '&continue_straight=true&alternatives=false'
      '&exclude=ferry'
      '&access_token=$token',
    );

    final body = await _httpGet(
      uri,
      timeout: Duration(seconds: 10 + pts.length),
    );
    if (body == null) return const [];

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final code = data['code']?.toString();
      if (code != null && code != 'Ok') {
        if (kDebugMode) debugPrint('directions code=$code');
        return const [];
      }
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return const [];
      return RoutePlanGeometry.parseGeoJsonLine(
        routes.first['geometry'] as Map<String, dynamic>?,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('directions parse: $e');
      return const [];
    }
  }

  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints, {
    bool snapWaypoints = true,
  }) async {
    if (waypoints.length < 2) return List.of(waypoints);
    final token = _mapboxToken;
    if (token == null) return List.of(waypoints);

    var pts = RoutePlanGeometry.sampleByDistance(
      waypoints,
      stepMeters: 120,
      maxPoints: 36,
    );

    if (snapWaypoints) {
      pts = await _snapWaypointsBatched(pts);
      pts = RoutePlanGeometry.dedupeNear(pts, minMeters: 12);
      if (pts.length < 2) return List.of(waypoints);
    }

    // نوافذ Directions متداخلة لنقاط تحكم كثيرة
    final driven = await _driveInChunks(pts, token);
    if (driven.length < 2) {
      return await snapToRoads(waypoints, minSpacingMeters: 15);
    }

    // تلميع Matching على النتيجة
    final polished = await snapToRoads(driven, minSpacingMeters: 12);
    final cleaned = RoutePlanGeometry.removeSpikes(
      polished.length >= 2 ? polished : driven,
      maxJumpMeters: 160,
    );
    return RoutePlanGeometry.simplifyPoints(cleaned, minDistanceMeters: 7);
  }

  Future<List<RoutePoint>> _snapWaypointsBatched(List<RoutePoint> pts) async {
    final snapped = <RoutePoint>[];
    const batch = 5;
    for (var i = 0; i < pts.length; i += batch) {
      final chunk = pts.sublist(i, math.min(i + batch, pts.length));
      final done = await Future.wait(chunk.map(snapPointToRoad));
      snapped.addAll(done);
      // تأخير بسيط لتجنب rate-limit
      if (i + batch < pts.length) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }
    return snapped;
  }

  Future<List<RoutePoint>> _driveInChunks(
    List<RoutePoint> pts,
    String token,
  ) async {
    if (pts.length <= _directionsWindow) {
      final one = await _directionsRequest(pts, token);
      return one.length >= 2 ? one : List.of(pts);
    }

    var out = <RoutePoint>[];
    // تداخل نقطة واحدة بين النوافذ لضمان اتصال المسار
    final step = _directionsWindow - 1;
    for (var i = 0; i < pts.length - 1; i += step) {
      final end = math.min(i + _directionsWindow, pts.length);
      final chunk = pts.sublist(i, end);
      if (chunk.length < 2) continue;

      var path = await _directionsRequest(chunk, token);

      // إن فشل النافذة: قطّعها إلى أزواج
      if (path.length < 2) {
        path = await _drivePairs(chunk, token);
      }

      // إن بقي فشل: خط مستقيم بين أطراف النافذة (نادر)
      if (path.length < 2) {
        path = List.of(chunk);
      }

      // ارفض قطعاً أطول بكثير من المسافة الجوية (مسار خاطئ التفافي)
      final air = RoutePlanGeometry.distanceMeters(
        chunk.first.latitude,
        chunk.first.longitude,
        chunk.last.latitude,
        chunk.last.longitude,
      );
      final road = RoutePlanGeometry.totalDistanceMeters(path);
      if (air > 80 && road > air * 4.5) {
        // أعد المحاولة بأزواج فقط
        final pairs = await _drivePairs(chunk, token);
        if (pairs.length >= 2) {
          final pairsLen = RoutePlanGeometry.totalDistanceMeters(pairs);
          if (pairsLen < road) path = pairs;
        }
      }

      out = out.isEmpty
          ? path
          : RoutePlanGeometry.mergePaths(out, path, joinToleranceM: 30);
    }

    return RoutePlanGeometry.dedupeNear(out, minMeters: 4);
  }

  Future<List<RoutePoint>> _drivePairs(
    List<RoutePoint> pts,
    String token,
  ) async {
    var out = <RoutePoint>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final seg = await _directionsRequest([pts[i], pts[i + 1]], token);
      final use = seg.length >= 2 ? seg : [pts[i], pts[i + 1]];
      out = out.isEmpty
          ? use
          : RoutePlanGeometry.mergePaths(out, use, joinToleranceM: 20);
    }
    return out;
  }

  Future<List<RoutePoint>> snapToRoads(
    List<RoutePoint> points, {
    double minSpacingMeters = 20,
  }) async {
    final simplified = RoutePlanGeometry.simplifyPoints(
      points,
      minDistanceMeters: minSpacingMeters,
    );
    if (simplified.length < 2) return simplified;

    final token = _mapboxToken;
    if (token == null) return simplified;

    try {
      // نوافذ Matching متداخلة بدل طلب عملاق واحد
      var out = <RoutePoint>[];
      final step = _matchWindow - 4;
      for (var i = 0; i < simplified.length; i += step) {
        final end = math.min(i + _matchWindow, simplified.length);
        final chunk = simplified.sublist(i, end);
        if (chunk.length < 2) continue;

        final matched = await _matchWindowRequest(chunk, token);
        final use = matched.length >= 2 ? matched : chunk;
        out = out.isEmpty
            ? use
            : RoutePlanGeometry.mergePaths(out, use, joinToleranceM: 25);

        if (end >= simplified.length) break;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      if (out.isEmpty) return simplified;

      final cleaned = RoutePlanGeometry.removeSpikes(out, maxJumpMeters: 150);
      return RoutePlanGeometry.simplifyPoints(cleaned, minDistanceMeters: 7);
    } catch (e) {
      if (kDebugMode) debugPrint('snapToRoads: $e');
      return simplified;
    }
  }

  Future<List<RoutePoint>> _matchWindowRequest(
    List<RoutePoint> sample,
    String token,
  ) async {
    final coords = sample.map(_coord).join(';');

    // نصف قطر متدرج: أضيق في الوسط، أوسع عند الأطراف
    final radiuses = <String>[];
    for (var i = 0; i < sample.length; i++) {
      final edge = i == 0 || i == sample.length - 1;
      radiuses.add(
        (edge ? pointSnapRadiusWideM : pointSnapRadiusM).toStringAsFixed(0),
      );
    }

    final uri = Uri.parse(
      'https://api.mapbox.com/matching/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&tidy=true'
      '&radiuses=${radiuses.join(';')}'
      '&gaps=ignore'
      '&access_token=$token',
    );

    final body = await _httpGet(uri);
    if (body == null) return const [];

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final code = data['code']?.toString();
      // NoMatch / NoSegment شائع — نرجع فارغ للـ fallback
      if (code != null && code != 'Ok') return const [];

      final matchings = data['matchings'] as List<dynamic>?;
      if (matchings == null || matchings.isEmpty) return const [];

      final snapped = <RoutePoint>[];
      for (final m in matchings) {
        if (m is! Map<String, dynamic>) continue;
        final path = RoutePlanGeometry.parseGeoJsonLine(
          m['geometry'] as Map<String, dynamic>?,
        );
        if (path.isEmpty) continue;
        if (snapped.isEmpty) {
          snapped.addAll(path);
        } else {
          snapped.addAll(path.skip(1));
        }
      }
      return snapped;
    } catch (_) {
      return const [];
    }
  }

  /// بناء مسار كامل محاذٍ للطرق من نقاط تحكم خام.
  Future<List<RoutePoint>> buildRoadAlignedRoute(
    List<RoutePoint> controlPoints,
  ) async {
    if (controlPoints.length < 2) return List.of(controlPoints);

    // 1) تنظيف أولي حسب المسافة
    final prepared = RoutePlanGeometry.sampleByDistance(
      RoutePlanGeometry.dedupeNear(controlPoints, minMeters: 8),
      stepMeters: 110,
      maxPoints: 42,
    );

    // 2) مسار قيادة عبر النقاط
    final viaDirs = await getDrivingPathThrough(
      prepared,
      snapWaypoints: true,
    );

    if (viaDirs.length >= 8) {
      final cleaned = RoutePlanGeometry.removeSpikes(
        viaDirs,
        maxJumpMeters: 150,
        maxTurnDegrees: 150,
      );
      return RoutePlanGeometry.simplifyPoints(cleaned, minDistanceMeters: 7);
    }

    // 3) fallback: Matching مباشر على نقاط التحكم
    final matched = await snapToRoads(prepared, minSpacingMeters: 12);
    if (matched.length >= 2) {
      return RoutePlanGeometry.removeSpikes(matched, maxJumpMeters: 150);
    }

    return RoutePlanGeometry.simplifyPoints(
      controlPoints,
      minDistanceMeters: 12,
    );
  }
}
