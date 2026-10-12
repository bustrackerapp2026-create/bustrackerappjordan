import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/passenger/presentation/journey_route_presentation.dart';

PlannedRoute _route({
  required String id,
  required RouteDirection direction,
}) {
  return PlannedRoute(
    id: id,
    createdBy: 'test',
    lineName: 'Shared line',
    direction: direction,
    points: const [
      RoutePoint(latitude: 31.9000, longitude: 35.9000),
      RoutePoint(latitude: 31.9000, longitude: 35.9050),
    ],
    status: PlannedRouteStatus.approved,
  );
}

VehicleTrip _trip({
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

void main() {
  test('returns no routes for empty journey options', () {
    expect(journeyOptionRoutesForPresentation(const []), isEmpty);
  });

  test('deduplicates multiple active vehicles for one route', () {
    final route = _route(id: 'route-1', direction: RouteDirection.outbound);
    final result = journeyOptionRoutesForPresentation([
      (route: route, vehicleTrip: _trip(
        id: 'trip-1',
        routeId: 'route-1',
        direction: 'outbound',
      )),
      (route: route, vehicleTrip: _trip(
        id: 'trip-2',
        routeId: 'route-1',
        direction: 'outbound',
      )),
    ]);

    expect(result, hasLength(1));
    expect(result.single, same(route));
  });

  test('keeps distinct routes with shared line name', () {
    final outbound = _route(
      id: 'route-1',
      direction: RouteDirection.outbound,
    );
    final returning = _route(
      id: 'route-2',
      direction: RouteDirection.returnTrip,
    );

    final result = journeyOptionRoutesForPresentation([
      (route: outbound, vehicleTrip: _trip(
        id: 'trip-1',
        routeId: 'route-1',
        direction: 'outbound',
      )),
      (route: returning, vehicleTrip: _trip(
        id: 'trip-2',
        routeId: 'route-2',
        direction: 'return',
      )),
    ]);

    expect(result, hasLength(2));
    expect(result[0], same(outbound));
    expect(result[1], same(returning));
  });

  test('preserves first-seen route order', () {
    final first = _route(id: 'route-1', direction: RouteDirection.outbound);
    final second = _route(id: 'route-2', direction: RouteDirection.outbound);

    final result = journeyOptionRoutesForPresentation([
      (route: second, vehicleTrip: _trip(
        id: 'trip-2',
        routeId: 'route-2',
        direction: 'outbound',
      )),
      (route: first, vehicleTrip: _trip(
        id: 'trip-1',
        routeId: 'route-1',
        direction: 'outbound',
      )),
      (route: second, vehicleTrip: _trip(
        id: 'trip-3',
        routeId: 'route-2',
        direction: 'outbound',
      )),
    ]);

    expect(result, hasLength(2));
    expect(result[0], same(second));
    expect(result[1], same(first));
  });
}