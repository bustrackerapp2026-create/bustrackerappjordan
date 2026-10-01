import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/route_candidate_discovery_service.dart';

PlannedRoute _route({
  required String id,
  required RouteDirection direction,
  required List<RoutePoint> points,
  String lineName = 'X',
  PlannedRouteStatus status = PlannedRouteStatus.approved,
}) {
  return PlannedRoute(
    id: id,
    createdBy: 'test',
    lineName: lineName,
    direction: direction,
    points: points,
    status: status,
  );
}

void main() {
  final policy = RouteCandidateDiscoveryPolicy(
    originMaxDistanceMeters: 30,
    destinationMaxDistanceMeters: 30,
  );

  test('returns qualifying route using alongMeters direction', () async {
    final route = _route(
      id: 'route-forward',
      direction: RouteDirection.outbound,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
    );

    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async => [route],
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9000,
      originLongitude: 35.9010,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9040,
    );

    expect(result.map((r) => r.id), ['route-forward']);
  });

  test('rejects route when origin is outside injected policy', () async {
    final route = _route(
      id: 'route-origin-far',
      direction: RouteDirection.outbound,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
    );

    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async => [route],
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9005,
      originLongitude: 35.9010,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9040,
    );

    expect(result, isEmpty);
  });

  test('rejects route when destination is outside injected policy', () async {
    final route = _route(
      id: 'route-destination-far',
      direction: RouteDirection.outbound,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
    );

    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async => [route],
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9000,
      originLongitude: 35.9010,
      destinationLatitude: 31.9005,
      destinationLongitude: 35.9040,
    );

    expect(result, isEmpty);
  });

  test('rejects route when destination is behind origin on route axis', () async {
    final route = _route(
      id: 'route-reverse',
      direction: RouteDirection.outbound,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
    );

    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async => [route],
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9000,
      originLongitude: 35.9040,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9010,
    );

    expect(result, isEmpty);
  });

  test('keeps distinct routes that share the same lineName', () async {
    final routeA = _route(
      id: 'route-a',
      direction: RouteDirection.outbound,
      lineName: 'X',
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
    );
    final routeB = _route(
      id: 'route-b',
      direction: RouteDirection.returnTrip,
      lineName: 'X',
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
    );

    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async => [routeA, routeB],
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9000,
      originLongitude: 35.9010,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9040,
    );

    expect(result.map((r) => r.id), ['route-a', 'route-b']);
    expect(result.map((r) => r.direction), [
      RouteDirection.outbound,
      RouteDirection.returnTrip,
    ]);
  });

  test('rejects non-approved routes', () async {
    final route = _route(
      id: 'route-pending',
      direction: RouteDirection.outbound,
      status: PlannedRouteStatus.pending,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9050),
      ],
    );

    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async => [route],
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9000,
      originLongitude: 35.9010,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9040,
    );

    expect(result, isEmpty);
  });

  test('returns no candidates for invalid coordinates without reading routes',
      () async {
    var readerCalls = 0;
    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async {
        readerCalls++;
        return const [];
      },
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: double.nan,
      originLongitude: 35.9010,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9040,
    );

    expect(result, isEmpty);
    expect(readerCalls, 0);
  });

  test('returns no candidates for longitude above 180 without reading routes',
      () async {
    var readerCalls = 0;
    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async {
        readerCalls++;
        return const [];
      },
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9000,
      originLongitude: 180.0001,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9040,
    );

    expect(result, isEmpty);
    expect(readerCalls, 0);
  });

  test('rejects invalid route geometry', () async {
    final route = _route(
      id: 'route-invalid',
      direction: RouteDirection.outbound,
      points: const [
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
        RoutePoint(latitude: 31.9000, longitude: 35.9000),
      ],
    );

    final service = RouteCandidateDiscoveryService(
      approvedRoutesReader: () async => [route],
      policy: policy,
    );

    final result = await service.discover(
      originLatitude: 31.9000,
      originLongitude: 35.9000,
      destinationLatitude: 31.9000,
      destinationLongitude: 35.9000,
    );

    expect(result, isEmpty);
  });
}
