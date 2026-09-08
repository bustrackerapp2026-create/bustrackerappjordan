import 'dart:math' as math;

import '../../models/route_point.dart';

/// مساعدات هندسية لمسارات الخطوط (مسافة، تبسيط، عيّنة، تنعيم).
class RoutePlanGeometry {
  RoutePlanGeometry._();

  static const int maxPointsToStore = 900;

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

  static double _deg(double r) => r * 180 / math.pi;

  /// زاوية الاتجاه بين نقطتين بالدرجات [0..360)
  static double bearingDegrees(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final y = math.sin(_rad(lng2 - lng1)) * math.cos(_rad(lat2));
    final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(_rad(lng2 - lng1));
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

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
    // DEBUG: Log first/last after parsing GeoJSON
    if (path.isNotEmpty) {
      debugPrintRoute(
        '🔹 parseGeoJsonLine OUTPUT',
        path.first,
        path.last,
        path.length,
      );
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
          2.5) {
        out.add(p);
      }
    }
    if (distanceMeters(
          out.last.latitude,
          out.last.longitude,
          end.latitude,
          end.longitude,
        ) >
        2.5) {
      out.add(end);
    } else if (out.isNotEmpty) {
      out[out.length - 1] = end;
    }
    // DEBUG: Log after stitching
    if (out.isNotEmpty) {
      debugPrintRoute(
        '🔹 stitchEndpoints OUTPUT',
        out.first,
        out.last,
        out.length,
      );
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

  /// إزالة القفزات الحادة (اختصار فوق مباني / أنفاق خاطئة)
  static List<RoutePoint> removeSpikes(
    List<RoutePoint> input, {
    double maxJumpMeters = 180,
    double maxTurnDegrees = 145,
  }) {
    if (input.length < 3) return List.of(input);

    final out = <RoutePoint>[input.first];
    for (var i = 1; i < input.length - 1; i++) {
      final prev = out.last;
      final cur = input[i];
      final next = input[i + 1];

      final d1 = distanceMeters(
        prev.latitude,
        prev.longitude,
        cur.latitude,
        cur.longitude,
      );
      final d2 = distanceMeters(
        cur.latitude,
        cur.longitude,
        next.latitude,
        next.longitude,
      );

      // قفزة مفاجئة طويلة جداً بين نقطتين متتاليتين
      if (d1 > maxJumpMeters && d2 < maxJumpMeters * 0.5) {
        continue;
      }

      if (out.isNotEmpty && i + 1 < input.length) {
        final b1 = bearingDegrees(
          prev.latitude,
          prev.longitude,
          cur.latitude,
          cur.longitude,
        );
        final b2 = bearingDegrees(
          cur.latitude,
          cur.longitude,
          next.latitude,
          next.longitude,
        );
        var turn = (b2 - b1).abs();
        if (turn > 180) turn = 360 - turn;

        // انعطاف حاد جداً مع مسافة قصيرة = غالباً ضوضاء مطابقة
        if (turn > maxTurnDegrees && d1 < 35 && d2 < 35) {
          continue;
        }
      }

      out.add(cur);
    }
    out.add(input.last);
    final result = dedupeNear(out, minMeters: 3);
    // DEBUG: Log after spike removal
    if (result.isNotEmpty) {
      debugPrintRoute(
        '🔹 removeSpikes OUTPUT',
        result.first,
        result.last,
        result.length,
      );
    }
    return result;
  }

  /// عيّنة نقاط تحكم بمسافة منتظمة تقريباً (أفضل من أخذ كل N فهرس)
  static List<RoutePoint> sampleByDistance(
    List<RoutePoint> input, {
    double stepMeters = 140,
    int maxPoints = 40,
  }) {
    if (input.length < 2) return List.of(input);

    final out = <RoutePoint>[input.first];
    var acc = 0.0;
    for (var i = 1; i < input.length; i++) {
      final d = distanceMeters(
        input[i - 1].latitude,
        input[i - 1].longitude,
        input[i].latitude,
        input[i].longitude,
      );
      acc += d;
      if (acc >= stepMeters) {
        out.add(input[i]);
        acc = 0;
      }
    }
    final last = input.last;
    if (distanceMeters(
          out.last.latitude,
          out.last.longitude,
          last.latitude,
          last.longitude,
        ) >
        15) {
      out.add(last);
    } else {
      out[out.length - 1] = last;
    }

    if (out.length > maxPoints) {
      return sampleEvenly(out, maxPoints);
    }
    // DEBUG: Log after sampling
    if (out.isNotEmpty) {
      debugPrintRoute(
        '🔹 sampleByDistance OUTPUT',
        out.first,
        out.last,
        out.length,
      );
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

  /// تبسيط Douglas-Peucker بالمتر تقريباً (إسقاط محلي)
  static List<RoutePoint> douglasPeucker(
    List<RoutePoint> points, {
    double epsilonMeters = 12,
  }) {
    if (points.length < 3) return List.of(points);

    double perpDist(RoutePoint p, RoutePoint a, RoutePoint b) {
      // تقريب محلي بالأمتار حول خط a→b
      final lat0 = _rad((a.latitude + b.latitude) / 2);
      final ax = a.longitude * 111320 * math.cos(lat0);
      final ay = a.latitude * 110540;
      final bx = b.longitude * 111320 * math.cos(lat0);
      final by = b.latitude * 110540;
      final px = p.longitude * 111320 * math.cos(lat0);
      final py = p.latitude * 110540;
      final dx = bx - ax;
      final dy = by - ay;
      if (dx.abs() < 1e-6 && dy.abs() < 1e-6) {
        return distanceMeters(p.latitude, p.longitude, a.latitude, a.longitude);
      }
      final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
      final tClamped = t.clamp(0.0, 1.0);
      final sx = ax + tClamped * dx;
      final sy = ay + tClamped * dy;
      final ddx = px - sx;
      final ddy = py - sy;
      return math.sqrt(ddx * ddx + ddy * ddy);
    }

    List<RoutePoint> recurse(List<RoutePoint> pts) {
      if (pts.length < 3) return pts;
      var maxD = 0.0;
      var idx = 0;
      final a = pts.first;
      final b = pts.last;
      for (var i = 1; i < pts.length - 1; i++) {
        final d = perpDist(pts[i], a, b);
        if (d > maxD) {
          maxD = d;
          idx = i;
        }
      }
      if (maxD > epsilonMeters) {
        final left = recurse(pts.sublist(0, idx + 1));
        final right = recurse(pts.sublist(idx));
        return [...left.sublist(0, left.length - 1), ...right];
      }
      return [a, b];
    }

    final result = recurse(points);
    if (result.length > maxPointsToStore) {
      return sampleEvenly(result, maxPointsToStore);
    }
    return result;
  }

  static List<RoutePoint> simplifyPoints(
    List<RoutePoint> input, {
    double minDistanceMeters = 25,
  }) {
    if (input.isEmpty) return const [];
    // أولاً مسافة دنيا ثم Douglas-Peucker أخف للحفاظ على انحناءات الشارع
    final spaced = dedupeNear(input, minMeters: minDistanceMeters * 0.55);
    if (spaced.length < 3) return spaced;
    final result = douglasPeucker(spaced, epsilonMeters: minDistanceMeters * 0.45);
    // DEBUG: Log after simplification
    if (result.isNotEmpty) {
      debugPrintRoute(
        '🔹 simplifyPoints OUTPUT',
        result.first,
        result.last,
        result.length,
      );
    }
    return result;
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

  /// دمج مسارين متتاليين مع إزالة التداخل عند الوصلة
  static List<RoutePoint> mergePaths(
    List<RoutePoint> a,
    List<RoutePoint> b, {
    double joinToleranceM = 25,
  }) {
    if (a.isEmpty) return List.of(b);
    if (b.isEmpty) return List.of(a);
    
    // DEBUG: Log inputs to mergePaths
    debugPrintRoute('🔹 mergePaths INPUT a', a.first, a.last, a.length);
    debugPrintRoute('🔹 mergePaths INPUT b', b.first, b.last, b.length);
    
    final out = List<RoutePoint>.of(a);
    var start = 0;
    if (distanceMeters(
          out.last.latitude,
          out.last.longitude,
          b.first.latitude,
          b.first.longitude,
        ) <
        joinToleranceM) {
      start = 1;
    }
    out.addAll(b.skip(start));
    final result = dedupeNear(out, minMeters: 3);
    
    // DEBUG: Log output
    if (result.isNotEmpty) {
      debugPrintRoute(
        '🔹 mergePaths OUTPUT',
        result.first,
        result.last,
        result.length,
      );
    }
    return result;
  }

  // DEBUG: Helper function
  static void debugPrintRoute(
    String label,
    RoutePoint first,
    RoutePoint last,
    int count,
  ) {
    print(
      '$label: $count points\n'
      '  First: (${first.latitude.toStringAsFixed(6)}, ${first.longitude.toStringAsFixed(6)})\n'
      '  Last:  (${last.latitude.toStringAsFixed(6)}, ${last.longitude.toStringAsFixed(6)})',
    );
  }
}
