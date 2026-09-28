import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/route_plan/route_plan_geometry.dart';
import 'package:jordan_bus_tracker_new/services/route_plan/route_polyline_projection.dart';
import 'package:jordan_bus_tracker_new/services/route_progress_calculator.dart';

void main() {
  group('RoutePolylineProjection', () {
    test('projects correctly on a straight route', () {
      final route = _straightRoute();
      final result = RoutePolylineProjection.project(
        routePoints: route,
        latitude: 31.0,
        longitude: 35.005,
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 0);
      expect(result.segmentT, closeTo(0.5, 1e-9));
      expect(
        result.alongMeters,
        closeTo(
          RoutePlanGeometry.distanceMeters(
            31.0,
            35.0,
            31.0,
            35.005,
          ),
          0.01,
        ),
      );
      expect(result.distanceToRouteMeters, closeTo(0, 1e-9));
    });

    test('accumulates alongMeters across multiple segments', () {
      final route = <RoutePoint>[
        const RoutePoint(latitude: 31.0, longitude: 35.0),
        const RoutePoint(latitude: 31.0, longitude: 35.01),
        const RoutePoint(latitude: 31.005, longitude: 35.01),
      ];
      final firstLength = RoutePlanGeometry.distanceMeters(
        31.0,
        35.0,
        31.0,
        35.01,
      );
      final secondHalf = RoutePlanGeometry.distanceMeters(
        31.0,
        35.01,
        31.0025,
        35.01,
      );

      final result = RoutePolylineProjection.project(
        routePoints: route,
        latitude: 31.0025,
        longitude: 35.01,
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 1);
      expect(result.segmentT, closeTo(0.5, 1e-9));
      expect(result.alongMeters, closeTo(firstLength + secondHalf, 0.01));
      expect(result.distanceToRouteMeters, closeTo(0, 1e-9));
    });

    test('returns endpoint projection with segmentT 0 and 1', () {
      final route = _straightRoute();

      final start = RoutePolylineProjection.project(
        routePoints: route,
        latitude: 31.0,
        longitude: 35.0,
      );
      final end = RoutePolylineProjection.project(
        routePoints: route,
        latitude: 31.0,
        longitude: 35.01,
      );

      expect(start, isNotNull);
      expect(start!.segmentIndex, 0);
      expect(start.segmentT, 0);
      expect(start.alongMeters, 0);

      expect(end, isNotNull);
      expect(end!.segmentIndex, 0);
      expect(end.segmentT, 1);
      expect(
        end.alongMeters,
        closeTo(RoutePlanGeometry.totalDistanceMeters(route), 0.01),
      );
    });

    test('returns projection and distance for an off-route point', () {
      final route = _straightRoute();

      final result = RoutePolylineProjection.project(
        routePoints: route,
        latitude: 31.0005,
        longitude: 35.005,
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 0);
      expect(result.segmentT, closeTo(0.5, 1e-9));
      expect(result.distanceToRouteMeters, greaterThan(50));
      expect(result.distanceToRouteMeters, lessThan(60));
    });
  });

  group('RouteProgressCalculator extraction regression', () {
    test('matches the pre-extraction projection behavior', () {
      final cases = <_ProjectionCase>[
        _ProjectionCase(
          routePoints: _straightRoute(),
          latitude: 31.0,
          longitude: 35.005,
          accuracy: 5,
        ),
        _ProjectionCase(
          routePoints: <RoutePoint>[
            const RoutePoint(latitude: 31.0, longitude: 35.0),
            const RoutePoint(latitude: 31.0, longitude: 35.01),
            const RoutePoint(latitude: 31.005, longitude: 35.01),
          ],
          latitude: 31.0025,
          longitude: 35.01,
          accuracy: 5,
        ),
        _ProjectionCase(
          routePoints: _straightRoute(),
          latitude: 31.0005,
          longitude: 35.005,
          accuracy: 0,
        ),
      ];

      for (final c in cases) {
        final legacy = _legacyProject(
          routePoints: c.routePoints,
          latitude: c.latitude,
          longitude: c.longitude,
          accuracy: c.accuracy,
        );
        final current = RouteProgressCalculator.project(
          routePoints: c.routePoints,
          latitude: c.latitude,
          longitude: c.longitude,
          accuracy: c.accuracy,
        );

        expect(current, isNotNull);
        expect(legacy, isNotNull);
        expect(current!.segmentIndex, legacy!.segmentIndex);
        expect(current.segmentT, closeTo(legacy.segmentT, 1e-12));
        expect(current.alongMeters, closeTo(legacy.alongMeters, 1e-9));
        expect(
          current.distanceToRouteMeters,
          closeTo(legacy.distanceToRouteMeters, 1e-9),
        );
        expect(current.progress, closeTo(legacy.progress, 1e-12));
      }
    });

    test('keeps the existing 100 m default projection limit', () {
      final result = RouteProgressCalculator.project(
        routePoints: _straightRoute(),
        latitude: 31.0015,
        longitude: 35.005,
        accuracy: null,
      );

      expect(result, isNull);
    });

    test('keeps the existing 250 m hard cap', () {
      final result = RouteProgressCalculator.project(
        routePoints: _straightRoute(),
        latitude: 31.002,
        longitude: 35.005,
        accuracy: 500,
      );

      expect(result, isNotNull);
      expect(result!.distanceToRouteMeters, lessThan(250));
    });
  });
}

List<RoutePoint> _straightRoute() {
  return const <RoutePoint>[
    RoutePoint(latitude: 31.0, longitude: 35.0),
    RoutePoint(latitude: 31.0, longitude: 35.01),
  ];
}

class _ProjectionCase {
  final List<RoutePoint> routePoints;
  final double latitude;
  final double longitude;
  final double? accuracy;

  const _ProjectionCase({
    required this.routePoints,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

class _LegacyProjection {
  final double progress;
  final double alongMeters;
  final double distanceToRouteMeters;
  final int segmentIndex;
  final double segmentT;

  const _LegacyProjection({
    required this.progress,
    required this.alongMeters,
    required this.distanceToRouteMeters,
    required this.segmentIndex,
    required this.segmentT,
  });
}

_LegacyProjection? _legacyProject({
  required List<RoutePoint> routePoints,
  required double latitude,
  required double longitude,
  double? accuracy,
}) {
  if (!_validCoordinate(latitude, longitude) || routePoints.length < 2) {
    return null;
  }

  for (final point in routePoints) {
    if (!_validCoordinate(point.latitude, point.longitude)) {
      return null;
    }
  }

  final totalRouteMeters = RoutePlanGeometry.totalDistanceMeters(routePoints);
  if (!totalRouteMeters.isFinite || totalRouteMeters <= 0) {
    return null;
  }

  final referenceLatitudeRadians = latitude * math.pi / 180.0;
  final metersPerLongitudeDegree =
      111320.0 * math.cos(referenceLatitudeRadians);
  const metersPerLatitudeDegree = 110540.0;

  double x(double pointLongitude) =>
      (pointLongitude - longitude) * metersPerLongitudeDegree;
  double y(double pointLatitude) =>
      (pointLatitude - latitude) * metersPerLatitudeDegree;

  var cumulativeBefore = 0.0;
  var bestDistanceSquared = double.infinity;
  _LegacyProjection? best;

  for (var i = 0; i < routePoints.length - 1; i++) {
    final a = routePoints[i];
    final b = routePoints[i + 1];

    final segmentLength = RoutePlanGeometry.distanceMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (!segmentLength.isFinite || segmentLength <= 0) {
      continue;
    }

    final ax = x(a.longitude);
    final ay = y(a.latitude);
    final bx = x(b.longitude);
    final by = y(b.latitude);

    final dx = bx - ax;
    final dy = by - ay;
    final segmentLengthSquared = dx * dx + dy * dy;
    if (!segmentLengthSquared.isFinite || segmentLengthSquared <= 0) {
      cumulativeBefore += segmentLength;
      continue;
    }

    final t = ((-ax) * dx + (-ay) * dy) / segmentLengthSquared;
    final clampedT = t.clamp(0.0, 1.0).toDouble();

    final projectedX = ax + clampedT * dx;
    final projectedY = ay + clampedT * dy;
    final distanceSquared =
        projectedX * projectedX + projectedY * projectedY;

    if (distanceSquared < bestDistanceSquared) {
      final alongMeters =
          cumulativeBefore + (segmentLength * clampedT);
      final progress =
          (alongMeters / totalRouteMeters).clamp(0.0, 1.0).toDouble();

      bestDistanceSquared = distanceSquared;
      best = _LegacyProjection(
        progress: progress,
        alongMeters: alongMeters,
        distanceToRouteMeters: math.sqrt(distanceSquared),
        segmentIndex: i,
        segmentT: clampedT,
      );
    }

    cumulativeBefore += segmentLength;
  }

  if (best == null) return null;

  final usableAccuracy =
      accuracy != null && accuracy.isFinite && accuracy >= 0 ? accuracy : 0.0;
  final maxDistance = math.min(
    RouteProgressCalculator.maxProjectionDistanceMeters,
    math.max(
      RouteProgressCalculator.minProjectionDistanceMeters,
      RouteProgressCalculator.accuracyMultiplier * usableAccuracy,
    ),
  );

  if (best.distanceToRouteMeters > maxDistance) return null;

  return best;
}

bool _validCoordinate(double latitude, double longitude) {
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
