import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/services/closest_criterion.dart';
import 'package:jordan_bus_tracker_new/services/vehicle_location_freshness_policy.dart';

void main() {
  final evaluatedAt = DateTime.utc(2026, 10, 2, 20, 0);
  final freshnessPolicy = VehicleLocationFreshnessPolicy(
    maxAge: Duration(minutes: 1),
  );

  VehicleTrip trip({
    GeoPoint? location = const GeoPoint(31.9000, 35.9000),
    DateTime? lastLocationAt,
    String id = 'trip-1',
    String routeId = 'route-1',
    String direction = 'outbound',
  }) {
    return VehicleTrip(
      id: id,
      driverId: 'driver-1',
      busNumber: '10',
      routeId: routeId,
      direction: direction,
      status: VehicleTripStatus.active,
      currentLocation: location,
      lastLocationAt: lastLocationAt,
    );
  }

  PlannedRoute route({
    String id = 'route-1',
    RouteDirection direction = RouteDirection.outbound,
  }) {
    return PlannedRoute(
      id: id,
      createdBy: 'test',
      lineName: 'Line $id',
      direction: direction,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9010, longitude: 35.9010),
      ],
      status: PlannedRouteStatus.approved,
    );
  }

  test('returns a comparable straight-line distance for a fresh location', () {
    final result = ClosestCriterion.evaluate(
      vehicleTrip: trip(
        lastLocationAt: evaluatedAt.subtract(const Duration(seconds: 30)),
      ),
      originLatitude: 31.9000,
      originLongitude: 35.9050,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.available);
    expect(result.distanceMeters, isNotNull);
    expect(result.distanceMeters!, greaterThan(0));
    expect(result.distanceMeters!, closeTo(473.0, 8.0));
  });

  test('returns zero distance for an exact Origin match', () {
    final result = ClosestCriterion.evaluate(
      vehicleTrip: trip(
        lastLocationAt: evaluatedAt.subtract(const Duration(seconds: 30)),
      ),
      originLatitude: 31.9000,
      originLongitude: 35.9000,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.available);
    expect(result.distanceMeters, closeTo(0, 0.000001));
  });

  test('returns unavailable when currentLocation is missing', () {
    final result = ClosestCriterion.evaluate(
      vehicleTrip: trip(
        location: null,
        lastLocationAt: evaluatedAt.subtract(const Duration(seconds: 30)),
      ),
      originLatitude: 31.9000,
      originLongitude: 35.9000,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.unavailable);
    expect(result.distanceMeters, isNull);
  });

  test('returns unavailable when lastLocationAt is missing', () {
    final result = ClosestCriterion.evaluate(
      vehicleTrip: trip(),
      originLatitude: 31.9000,
      originLongitude: 35.9000,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.unavailable);
  });

  test('returns unavailable when location is stale', () {
    final result = ClosestCriterion.evaluate(
      vehicleTrip: trip(
        lastLocationAt: evaluatedAt.subtract(
          const Duration(minutes: 1, seconds: 1),
        ),
      ),
      originLatitude: 31.9000,
      originLongitude: 35.9000,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.unavailable);
  });

  test('returns unavailable when location timestamp is in the future', () {
    final result = ClosestCriterion.evaluate(
      vehicleTrip: trip(
        lastLocationAt: evaluatedAt.add(const Duration(seconds: 1)),
      ),
      originLatitude: 31.9000,
      originLongitude: 35.9000,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.unavailable);
  });

  test('returns unavailable for invalid Origin coordinates', () {
    final result = ClosestCriterion.evaluate(
      vehicleTrip: trip(
        lastLocationAt: evaluatedAt.subtract(const Duration(seconds: 30)),
      ),
      originLatitude: double.nan,
      originLongitude: 35.9000,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.unavailable);
  });

  test('does not invalidate the underlying VehicleTrip when criterion is unavailable', () {
    final vehicleTrip = trip();

    final result = ClosestCriterion.evaluate(
      vehicleTrip: vehicleTrip,
      originLatitude: 31.9000,
      originLongitude: 35.9000,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result.status, ClosestCriterionStatus.unavailable);
    expect(vehicleTrip.isActive, isTrue);
    expect(vehicleTrip.id, 'trip-1');
  });

  test('tie-break orders by route id, then direction, then vehicleTrip id', () {
    final routeA = route(id: 'route-a');
    final routeB = route(id: 'route-b');
    final tripA = trip(id: 'trip-a');
    final tripB = trip(id: 'trip-b');

    expect(
      ClosestCriterion.compareTieBreak(
        firstRoute: routeA,
        firstVehicleTrip: tripA,
        secondRoute: routeB,
        secondVehicleTrip: tripA,
      ),
      lessThan(0),
    );

    expect(
      ClosestCriterion.compareTieBreak(
        firstRoute: route(
          id: 'same-route',
          direction: RouteDirection.outbound,
        ),
        firstVehicleTrip: tripA,
        secondRoute: route(
          id: 'same-route',
          direction: RouteDirection.returnTrip,
        ),
        secondVehicleTrip: tripA,
      ),
      lessThan(0),
    );

    expect(
      ClosestCriterion.compareTieBreak(
        firstRoute: route(id: 'same-route'),
        firstVehicleTrip: tripA.copyWith(routeId: 'same-route'),
        secondRoute: route(id: 'same-route'),
        secondVehicleTrip: tripB.copyWith(routeId: 'same-route'),
      ),
      lessThan(0),
    );

    expect(
      ClosestCriterion.compareTieBreak(
        firstRoute: route(id: 'same-route'),
        firstVehicleTrip: tripA,
        secondRoute: route(id: 'same-route'),
        secondVehicleTrip: tripA,
      ),
      0,
    );
  });

  test('distance is deterministic for identical inputs', () {
    final vehicleTrip = trip(
      lastLocationAt: evaluatedAt.subtract(const Duration(seconds: 30)),
    );
    final first = ClosestCriterion.evaluate(
      vehicleTrip: vehicleTrip,
      originLatitude: 31.9000,
      originLongitude: 35.9050,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );
    final second = ClosestCriterion.evaluate(
      vehicleTrip: vehicleTrip,
      originLatitude: 31.9000,
      originLongitude: 35.9050,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(first.status, second.status);
    expect(first.distanceMeters, second.distanceMeters);
    expect(first.distanceMeters, isNot(isNaN));
  });
}
