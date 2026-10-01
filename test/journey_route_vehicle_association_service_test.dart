import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/services/journey_route_vehicle_association_service.dart';
import 'package:jordan_bus_tracker_new/services/vehicle_trip_service.dart';

void main() {
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
        RoutePoint(latitude: 31.9010, longitude: 35.9010),
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

  VehicleTripService vehicleTripService(
    Future<List<VehicleTrip>> Function({
      required String routeId,
      required String direction,
    }) reader,
  ) {
    return VehicleTripService.forTesting(
      activeTripsForRouteReader: reader,
    );
  }

  test('returns zero associations when a route has no active vehicles',
      () async {
    final service = JourneyRouteVehicleAssociationService(
      vehicleTripService: vehicleTripService(
        ({required routeId, required direction}) async => const [],
      ),
    );

    final result = await service.associate(
      routeCandidates: [route(id: 'route-1')],
    );

    expect(result, isEmpty);
  });

  test('creates one association for each matching active vehicle', () async {
    final candidateRoute = route(id: 'route-1');
    final vehicleOne = trip(
      id: 'trip-1',
      routeId: 'route-1',
      direction: 'outbound',
    );
    final vehicleTwo = trip(
      id: 'trip-2',
      routeId: 'route-1',
      direction: 'outbound',
    );

    final service = JourneyRouteVehicleAssociationService(
      vehicleTripService: vehicleTripService(
        ({required routeId, required direction}) async => [
          vehicleOne,
          vehicleTwo,
        ],
      ),
    );

    final result = await service.associate(
      routeCandidates: [candidateRoute],
    );

    expect(result, hasLength(2));
    expect(
      result.map((item) => item.route.id),
      ['route-1', 'route-1'],
    );
    expect(
      result.map((item) => item.vehicleTrip.id),
      ['trip-1', 'trip-2'],
    );
    expect(result[0].route, same(candidateRoute));
    expect(result[0].vehicleTrip, same(vehicleOne));
    expect(result[1].vehicleTrip, same(vehicleTwo));
  });

  test('does not associate a vehicle from a different route identity',
      () async {
    final candidateRoute = route(id: 'route-1');
    final service = JourneyRouteVehicleAssociationService(
      vehicleTripService: vehicleTripService(
        ({required routeId, required direction}) async => [
          trip(
            id: 'wrong-route',
            routeId: 'route-2',
            direction: 'outbound',
          ),
        ],
      ),
    );

    final result = await service.associate(
      routeCandidates: [candidateRoute],
    );

    expect(result, isEmpty);
  });

  test('does not associate a vehicle from a different direction', () async {
    final candidateRoute = route(id: 'route-1');
    final service = JourneyRouteVehicleAssociationService(
      vehicleTripService: vehicleTripService(
        ({required routeId, required direction}) async => [
          trip(
            id: 'wrong-direction',
            routeId: 'route-1',
            direction: 'return',
          ),
        ],
      ),
    );

    final result = await service.associate(
      routeCandidates: [candidateRoute],
    );

    expect(result, isEmpty);
  });

  test('does not create a Cartesian product across route candidates',
      () async {
    final routeOne = route(id: 'route-1');
    final routeTwo = route(
      id: 'route-2',
      direction: RouteDirection.returnTrip,
    );

    final service = JourneyRouteVehicleAssociationService(
      vehicleTripService: vehicleTripService(
        ({required routeId, required direction}) async {
          if (routeId == 'route-1' && direction == 'outbound') {
            return [
              trip(
                id: 'trip-1',
                routeId: 'route-1',
                direction: 'outbound',
              ),
            ];
          }

          if (routeId == 'route-2' && direction == 'return') {
            return [
              trip(
                id: 'trip-2',
                routeId: 'route-2',
                direction: 'return',
              ),
            ];
          }

          return const [];
        },
      ),
    );

    final result = await service.associate(
      routeCandidates: [routeOne, routeTwo],
    );

    expect(result, hasLength(2));
    expect(
      result.map(
        (item) => '${item.route.id}:${item.vehicleTrip.id}',
      ),
      ['route-1:trip-1', 'route-2:trip-2'],
    );
  });

  test('propagates active vehicle read failures', () async {
    final error = VehicleTripServiceException(
      'vehicle read failed',
      code: 'unavailable',
    );

    final service = JourneyRouteVehicleAssociationService(
      vehicleTripService: vehicleTripService(
        ({required routeId, required direction}) async {
          throw error;
        },
      ),
    );

    await expectLater(
      service.associate(routeCandidates: [route(id: 'route-1')]),
      throwsA(same(error)),
    );
  });
}
