import 'dart:math' as math;

import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_plan/route_polyline_projection.dart';

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

    final projected = RoutePolylineProjection.project(
      routePoints: routePoints,
      latitude: latitude,
      longitude: longitude,
    );
    if (projected == null) return null;

    final maxDistance = _maxProjectionDistanceMeters(accuracy);
    if (projected.distanceToRouteMeters > maxDistance) return null;

    final progress =
        (projected.alongMeters / totalRouteMeters).clamp(0.0, 1.0).toDouble();

    return RouteProgressProjection(
      progress: progress,
      alongMeters: projected.alongMeters,
      distanceToRouteMeters: projected.distanceToRouteMeters,
      segmentIndex: projected.segmentIndex,
      segmentT: projected.segmentT,
    );
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
