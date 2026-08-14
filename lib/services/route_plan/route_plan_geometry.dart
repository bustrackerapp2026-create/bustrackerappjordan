import 'dart:math' as math;

import '../../models/route_point.dart';

/// مساعدات هندسية لمسارات الخطوط (مسافة، تبسيط، عيّنة).
class RoutePlanGeometry {
  RoutePlanGeometry._();

  static const int maxPointsToStore = 800;

  static double distanceMeters(
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

  static double _rad(double d) => d * math.pi / 180;

  static List<RoutePoint> parseGeoJsonLine(Map<String, dynamic>? geom) {
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

  static List<RoutePoint> stitchEndpoints(
    List<RoutePoint> path,
    RoutePoint start,
    RoutePoint end,
  ) {
    final out = <RoutePoint>[start];
    for (final p in path) {
      if (distanceMeters(
            out.last.latitude,
            out.last.longitude,
            p.latitude,
            p.longitude,
          ) >=
          3) {
        out.add(p);
      }
    }
    if (distanceMeters(
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

  static List<RoutePoint> dedupeNear(
    List<RoutePoint> input, {
    double minMeters = 5,
  }) {
    if (input.isEmpty) return const [];
    final out = <RoutePoint>[input.first];
    for (var i = 1; i < input.length; i++) {
      final p = input[i];
      if (distanceMeters(
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

  static List<RoutePoint> sampleEvenly(List<RoutePoint> input, int maxCount) {
    if (input.length <= maxCount) return input;
    final out = <RoutePoint>[];
    final step = (input.length - 1) / (maxCount - 1);
    for (var i = 0; i < maxCount; i++) {
      out.add(input[(i * step).round()]);
    }
    return out;
  }

  static List<RoutePoint> simplifyPoints(
    List<RoutePoint> input, {
    double minDistanceMeters = 25,
  }) {
    if (input.isEmpty) return const [];
    final out = <RoutePoint>[input.first];
    for (var i = 1; i < input.length; i++) {
      final prev = out.last;
      final cur = input[i];
      if (distanceMeters(
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
      if (distanceMeters(
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

  static double totalDistanceMeters(List<RoutePoint> points) {
    if (points.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += distanceMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return sum;
  }
}
