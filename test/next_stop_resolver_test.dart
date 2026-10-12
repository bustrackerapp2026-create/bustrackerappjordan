import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';
import 'package:jordan_bus_tracker_new/services/next_stop_resolver.dart';
import 'package:jordan_bus_tracker_new/services/route_plan/route_polyline_projection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('NextStopResolver', () {
    test('returns null when there are no stops', () {
      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: const [],
        isEligible: (_) => true,
      );

      expect(result, isNull);
    });

    test('returns null for invalid vehicleAlongMeters', () {
      final stop = _projectedStop(alongMeters: 1200, order: 0);

      expect(
        NextStopResolver.resolve(
          vehicleAlongMeters: double.nan,
          projectedStops: [stop],
          isEligible: (_) => true,
        ),
        isNull,
      );

      expect(
        NextStopResolver.resolve(
          vehicleAlongMeters: double.infinity,
          projectedStops: [stop],
          isEligible: (_) => true,
        ),
        isNull,
      );

      expect(
        NextStopResolver.resolve(
          vehicleAlongMeters: -1,
          projectedStops: [stop],
          isEligible: (_) => true,
        ),
        isNull,
      );
    });

    test('excludes an ineligible stop from candidates', () {
      final stop = _projectedStop(alongMeters: 1200, order: 0);

      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: [stop],
        isEligible: (_) => false,
      );

      expect(result, isNull);
    });

    test('excludes a stop behind the vehicle', () {
      final stop = _projectedStop(alongMeters: 800, order: 0);

      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: [stop],
        isEligible: (_) => true,
      );

      expect(result, isNull);
    });

    test('excludes a stop at the same alongMeters as the vehicle', () {
      final stop = _projectedStop(alongMeters: 1000, order: 0);

      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: [stop],
        isEligible: (_) => true,
      );

      expect(result, isNull);
    });

    test('selects the nearest eligible stop ahead on the route axis', () {
      final farther = _projectedStop(alongMeters: 1800, order: 0);
      final nearer = _projectedStop(alongMeters: 1300, order: 1);

      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: [farther, nearer],
        isEligible: (_) => true,
      );

      expect(result, same(nearer));
    });

    test('lets eligibility reject a far off-route projection', () {
      final nearRoute = _projectedStop(
        alongMeters: 1300,
        distanceToRouteMeters: 20,
        order: 0,
      );
      final farFromRoute = _projectedStop(
        alongMeters: 1200,
        distanceToRouteMeters: 1200,
        order: 1,
      );

      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: [farFromRoute, nearRoute],
        isEligible: (candidate) =>
            candidate.projection.distanceToRouteMeters <= 100,
      );

      expect(result, same(nearRoute));
    });

    test('uses order as the tie-breaker for equal alongMeters', () {
      final higherOrder = _projectedStop(alongMeters: 1300, order: 3);
      final lowerOrder = _projectedStop(alongMeters: 1300, order: 1);

      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: [higherOrder, lowerOrder],
        isEligible: (_) => true,
      );

      expect(result, same(lowerOrder));
    });

    test('returns null when no eligible stop is ahead', () {
      final behind = _projectedStop(alongMeters: 800, order: 0);
      final ineligible = _projectedStop(alongMeters: 1500, order: 1);

      final result = NextStopResolver.resolve(
        vehicleAlongMeters: 1000,
        projectedStops: [behind, ineligible],
        isEligible: (candidate) => candidate.stop.id == 'eligible-other',
      );

      expect(result, isNull);
    });
  });
}

ProjectedPlannedRouteStop _projectedStop({
  required double alongMeters,
  required int order,
  double distanceToRouteMeters = 0,
}) {
  final stop = PlannedRouteStopModel(
    id: 'stop-$order',
    name: 'Stop $order',
    location: const GeoPoint(31.95, 35.91),
    order: order,
  );

  return ProjectedPlannedRouteStop(
    stop: stop,
    projection: RoutePolylineProjection(
      alongMeters: alongMeters,
      distanceToRouteMeters: distanceToRouteMeters,
      segmentIndex: 0,
      segmentT: 0,
    ),
  );
}
