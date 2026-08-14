import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/route_point.dart';
import 'route_plan_geometry.dart';

/// طلبات Mapbox Matching / Directions لمحاذاة المسارات على الشارع.
class RoutePlanMapbox {
  RoutePlanMapbox._();
  static final RoutePlanMapbox instance = RoutePlanMapbox._();

  /// نصف قطر لصق النقطة على أقرب شارع (متر)
  static const double pointSnapRadiusM = 55;

  String? get _mapboxToken {
    final t = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (t.isEmpty || t == 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') return null;
    return t;
  }

  Future<String?> _httpGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 14),
  }) async {
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

  Future<RoutePoint> snapPointToRoad(RoutePoint point) async {
    final token = _mapboxToken;
    if (token == null) return point;

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

      final path = RoutePlanGeometry.parseGeoJsonLine(
        matchings.first['geometry'] as Map<String, dynamic>?,
      );
      if (path.isEmpty) return point;

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
      debugPrint('snapPointToRoad: $e');
      return point;
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

      final path = RoutePlanGeometry.parseGeoJsonLine(
        routes.first['geometry'] as Map<String, dynamic>?,
      );
      if (path.length < 2) return [a, b];

      return RoutePlanGeometry.stitchEndpoints(path, a, b);
    } catch (e) {
      debugPrint('getDrivingPath: $e');
      return [a, b];
    }
  }

  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints, {
    bool snapWaypoints = true,
  }) async {
    if (waypoints.length < 2) return List.of(waypoints);
    final token = _mapboxToken;
    if (token == null) return List.of(waypoints);

    List<RoutePoint> pts = List.of(waypoints);
    if (snapWaypoints) {
      final snapped = <RoutePoint>[];
      for (var i = 0; i < pts.length; i += 6) {
        final chunk = pts.sublist(i, math.min(i + 6, pts.length));
        final done = await Future.wait(chunk.map(snapPointToRoad));
        snapped.addAll(done);
      }
      pts = RoutePlanGeometry.dedupeNear(snapped, minMeters: 8);
      if (pts.length < 2) return List.of(waypoints);
    }

    final routePts =
        pts.length <= 25 ? pts : RoutePlanGeometry.sampleEvenly(pts, 25);

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
      final path = RoutePlanGeometry.parseGeoJsonLine(
        routes.first['geometry'] as Map<String, dynamic>?,
      );
      if (path.length < 2) return await snapToRoads(waypoints);

      final polished = await snapToRoads(path, minSpacingMeters: 10);
      return polished.length >= 2
          ? RoutePlanGeometry.simplifyPoints(polished, minDistanceMeters: 8)
          : RoutePlanGeometry.simplifyPoints(path, minDistanceMeters: 8);
    } catch (e) {
      debugPrint('getDrivingPathThrough: $e');
      return await snapToRoads(waypoints);
    }
  }

  Future<List<RoutePoint>> _driveInChunks(List<RoutePoint> pts) async {
    final out = <RoutePoint>[];
    const chunkSize = 10;
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
            final parsed = RoutePlanGeometry.parseGeoJsonLine(
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
    return RoutePlanGeometry.dedupeNear(out, minMeters: 5);
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

    try {
      final token = _mapboxToken;
      if (token == null) return simplified;

      final sample = simplified.length <= 95
          ? simplified
          : RoutePlanGeometry.simplifyPoints(
              simplified,
              minDistanceMeters: minSpacingMeters * 1.8,
            );

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

      return snapped.isNotEmpty
          ? RoutePlanGeometry.simplifyPoints(snapped, minDistanceMeters: 8)
          : simplified;
    } catch (e) {
      debugPrint('snapToRoads: $e');
      return simplified;
    }
  }

  Future<List<RoutePoint>> buildRoadAlignedRoute(
    List<RoutePoint> controlPoints,
  ) async {
    if (controlPoints.length < 2) return List.of(controlPoints);

    final viaDirs = await getDrivingPathThrough(
      controlPoints,
      snapWaypoints: true,
    );
    if (viaDirs.length >= 2) {
      return RoutePlanGeometry.simplifyPoints(viaDirs, minDistanceMeters: 8);
    }

    final matched = await snapToRoads(
      controlPoints,
      minSpacingMeters: 12,
    );
    return matched.length >= 2
        ? matched
        : RoutePlanGeometry.simplifyPoints(
            controlPoints,
            minDistanceMeters: 10,
          );
  }
}
