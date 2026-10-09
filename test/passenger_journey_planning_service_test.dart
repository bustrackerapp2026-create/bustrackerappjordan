import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/services/journey_route_vehicle_association_service.dart';
import 'package:jordan_bus_tracker_new/services/passenger_journey_planning_service.dart';
import 'package:jordan_bus_tracker_new/services/route_candidate_discovery_service.dart';
import 'package:jordan_bus_tracker_new/services/vehicle_trip_service.dart';

void main() {
  final policy = RouteCandidateDiscoveryPolicy(
    originMaxDistanceMeters: 30,
    destinationMaxDistanceMeters: 30,
  );

  PlannedRoute route({
    required String id,
    RouteDirection direction = RouteDirection.outbound,
  }) {
    return PlannedRoute(
      id: id,
      createdBy: 'test',
      lineName: 'Line $id',
      direction: direction,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
      status: PlannedRouteStatus.approved,
    );
  }

  VehicleTrip trip({
    required String id,
    required String routeId,
    required String direction,
  }) {
    return VehicleTrip(
      id: id,
      driverId: 'driver-$id',
      busNumber: 'bus-$id',
      routeId: routeId,
      direction: direction,
      status: VehicleTripStatus.active,
    );
  }

  RouteCandidateDiscoveryService discoveryService({
    required Future<List<PlannedRoute>> Function() reader,
  }) {
    return RouteCandidateDiscoveryService(
      approvedRoutesReader: reader,
      policy: policy,
    );
  }

  JourneyRouteVehicleAssociationService associationService({
    required Future<List<VehicleTrip>> Function({
      required String routeId,
      required String direction,
    }) reader,
  }) {
    return JourneyRouteVehicleAssociationService(
      vehicleTripService: VehicleTripService.forTesting(
        activeTripsForRouteReader: reader,
      ),
    );
  }

  PassengerJourneyPlanningService planningService({
    required RouteCandidateDiscoveryService discovery,
    required JourneyRouteVehicleAssociationService association,
  }) {
    return PassengerJourneyPlanningService(
      routeCandidateDiscoveryService: discovery,
      associationService: association,
    );
  }

  Future<List<({
    PlannedRoute route,
    VehicleTrip vehicleTrip,
  })>> plan(
    PassengerJourneyPlanningService service,
  ) {
    return service.plan(
      originLatitude: 31.9000,
      originLongitude: 35.9010,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9040,
    );
  }

  test(
    'orchestrates discovery then association and preserves original objects',
    () async {
      final candidateRoute = route(id: 'route-1');
      final activeVehicle = trip(
        id: 'trip-1',
        routeId: 'route-1',
        direction: 'outbound',
      );

      final discovery = discoveryService(
        reader: () async => [candidateRoute],
      );
      final association = associationService(
        reader: ({required routeId, required direction}) async => [
          activeVehicle,
        ],
      );

      final result = await plan(
        planningService(
          discovery: discovery,
          association: association,
        ),
      );

      expect(result, hasLength(1));
      expect(result.single.route, same(candidateRoute));
      expect(result.single.vehicleTrip, same(activeVehicle));
    },
  );

  test('returns zero without calling association when discovery returns no routes',
      () async {
    var associationCalls = 0;

    final discovery = discoveryService(
      reader: () async => const [],
    );
    final association = associationService(
      reader: ({required routeId, required direction}) async {
        associationCalls++;
        return const [];
      },
    );

    final result = await plan(
      planningService(
        discovery: discovery,
        association: association,
      ),
    );

    expect(result, isEmpty);
    expect(associationCalls, 0);
  });

  test('returns zero when routes exist but association returns no vehicles',
      () async {
    final discovery = discoveryService(
      reader: () async => [route(id: 'route-1')],
    );
    final association = associationService(
      reader: ({required routeId, required direction}) async => const [],
    );

    final result = await plan(
      planningService(
        discovery: discovery,
        association: association,
      ),
    );

    expect(result, isEmpty);
  });

  test('propagates discovery failures unchanged', () async {
    final error = StateError('route discovery failed');

    final discovery = discoveryService(
      reader: () async {
        throw error;
      },
    );
    final association = associationService(
      reader: ({required routeId, required direction}) async => const [],
    );

    await expectLater(
      plan(
        planningService(
          discovery: discovery,
          association: association,
        ),
      ),
      throwsA(same(error)),
    );
  });

  test('propagates association failures unchanged', () async {
    final error = StateError('vehicle association failed');

    final discovery = discoveryService(
      reader: () async => [route(id: 'route-1')],
    );
    final association = associationService(
      reader: ({required routeId, required direction}) async {
        throw error;
      },
    );

    await expectLater(
      plan(
        planningService(
          discovery: discovery,
          association: association,
        ),
      ),
      throwsA(same(error)),
    );
  });
}
