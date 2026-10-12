import 'dart:math' as math;

import '../../models/route_point.dart';
import 'route_plan_geometry.dart';

/// نتيجة إسقاط نقطة على هندسة polyline.
///
/// Primitive هندسي مستقل؛ لا يعرف GPS أو Stop أو VehicleTrip أو Firestore.
class RoutePolylineProjection {
  final double alongMeters;
  final double distanceToRouteMeters;
  final int segmentIndex;
  final double segmentT;

  const RoutePolylineProjection({
    required this.alongMeters,
    required this.distanceToRouteMeters,
    required this.segmentIndex,
    required this.segmentT,
  });

  /// يبحث عن أقرب إسقاط هندسي للنقطة على كامل الـpolyline.
  ///
  /// لا يطبق أي سياسة خاصة بـGPS مثل accuracy أو حد أقصى لمسافة
  /// الإسقاط. هذه مسؤولية الطبقة المستهلكة للـprimitive.
  static RoutePolylineProjection? project({
    required List<RoutePoint> routePoints,
    required double latitude,
    required double longitude,
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

    // Local meter projection around the current latitude keeps the arithmetic
    // numerically stable without requiring a network/geodesic API.
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
    RoutePolylineProjection? best;

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

      // The projected input point is the local origin (0, 0).
      final t = ((-ax) * dx + (-ay) * dy) / segmentLengthSquared;
      final clampedT = t.clamp(0.0, 1.0).toDouble();

      final projectedX = ax + clampedT * dx;
      final projectedY = ay + clampedT * dy;
      final distanceSquared =
          projectedX * projectedX + projectedY * projectedY;

      if (distanceSquared < bestDistanceSquared) {
        final alongMeters =
            cumulativeBefore + (segmentLength * clampedT);

        bestDistanceSquared = distanceSquared;
        best = RoutePolylineProjection(
          alongMeters: alongMeters,
          distanceToRouteMeters: math.sqrt(distanceSquared),
          segmentIndex: i,
          segmentT: clampedT,
        );
      }

      cumulativeBefore += segmentLength;
    }

    return best;
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
