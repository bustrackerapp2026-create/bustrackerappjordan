import 'dart:math' as math;

import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';

/// نتيجة إسقاط GPS على هندسة PlannedRoute.
class RouteProgressProjection {
  final double progress;
  final double alongMeters;
  final double distanceToRouteMeters;
  final int segmentIndex;
  final double segmentT;

  const RouteProgressProjection({
    required this.progress,
    required this.alongMeters,
    required this.distanceToRouteMeters,
    required this.segmentIndex,
    required this.segmentT,
  });
}

/// حساب هندسي مستقل لـRouteProgress.
///
/// هذه الطبقة لا تعرف Firestore أو DriverTrackingHub أو واجهة الخريطة.
class RouteProgressCalculator {
  RouteProgressCalculator._();

  static const double minProjectionDistanceMeters = 100.0;
  static const double accuracyMultiplier = 2.0;
  static const double maxProjectionDistanceMeters = 250.0;

  static RouteProgressProjection? project({
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

    // Local meter projection around the current GPS latitude keeps the
    // arithmetic numerically stable without requiring a network/geodesic API.
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
    RouteProgressProjection? best;

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

      // The GPS position is the local origin (0, 0).
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
        best = RouteProgressProjection(
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

    final maxDistance = _maxProjectionDistanceMeters(accuracy);
    if (best.distanceToRouteMeters > maxDistance) return null;

    return best;
  }

  static double _maxProjectionDistanceMeters(double? accuracy) {
    final usableAccuracy =
        accuracy != null && accuracy.isFinite && accuracy >= 0
            ? accuracy
            : 0.0;
    return math.min(
      maxProjectionDistanceMeters,
      math.max(
        minProjectionDistanceMeters,
        accuracyMultiplier * usableAccuracy,
      ),
    );
  }

  static bool _validCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
