import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/stop_runtime_snapshot_resolver.dart';
import 'package:jordan_bus_tracker_new/services/stop_state_resolver.dart';

void main() {
  const route = [
    RoutePoint(latitude: 31.0000, longitude: 35.0000),
    RoutePoint(latitude: 31.0000, longitude: 35.0100),
  ];

  final statePolicy = StopStatePolicy(
    atStopRadius: 20,
    approachingDistance: 200,
  );

  PlannedRouteStopModel stop(
    String id,
    double longitude, {
    int order = 0,
  }) {
    return PlannedRouteStopModel(
      id: id,
      name: id,
      location: GeoPoint(31.0000, longitude),
      order: order,
    );
  }

  test('returns an empty snapshot when no fixed stops exist', () {
    final snapshot = StopRuntimeSnapshotResolver.resolve(
      routePoints: route,
      vehicleAlongMeters: 500,
      stops: const [],
      isEligible: (_) => true,
      statePolicy: statePolicy,
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.eligibleProjectedStops, isEmpty);
    expect(snapshot.nextStop, isNull);
    expect(snapshot.statesByStopId, isEmpty);
  });

  test('projects eligible stops and resolves the nearest forward stop', () {
    final snapshot = StopRuntimeSnapshotResolver.resolve(
      routePoints: route,
      vehicleAlongMeters: 100,
      stops: [
        stop('behind', 35.0020, order: 0),
        stop('near', 35.0050, order: 1),
        stop('far', 35.0080, order: 2),
      ],
      isEligible: (candidate) => candidate.stop.id != 'behind',
      statePolicy: statePolicy,
    );

    expect(snapshot, isNotNull);
    expect(
      snapshot!.eligibleProjectedStops.map((candidate) => candidate.stop.id),
      ['near', 'far'],
    );
    expect(snapshot.nextStop, isNotNull);
    expect(snapshot.nextStop!.stop.id, 'near');
  });

  test(
    'classifies the eligible stop state from accepted along-route position',
    () {
      final snapshot = StopRuntimeSnapshotResolver.resolve(
        routePoints: route,
        vehicleAlongMeters: 700,
        stops: [stop('approaching', 35.0085)],
        isEligible: (_) => true,
        statePolicy: statePolicy,
      );

      expect(snapshot, isNotNull);
      expect(
        snapshot!.statesByStopId['approaching'],
        StopState.approaching,
      );
    },
  );

  test('excludes ineligible stops from next-stop and state results', () {
    final snapshot = StopRuntimeSnapshotResolver.resolve(
      routePoints: route,
      vehicleAlongMeters: 500,
      stops: [
        stop('ineligible', 35.0060),
        stop('eligible', 35.0080, order: 1),
      ],
      isEligible: (candidate) => candidate.stop.id == 'eligible',
      statePolicy: statePolicy,
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.eligibleProjectedStops.single.stop.id, 'eligible');
    expect(snapshot.nextStop!.stop.id, 'eligible');
    expect(snapshot.statesByStopId.containsKey('ineligible'), isFalse);
  });

  test('returns null when vehicleAlongMeters is outside the route axis', () {
    final snapshot = StopRuntimeSnapshotResolver.resolve(
      routePoints: route,
      vehicleAlongMeters: -1,
      stops: [stop('stop', 35.0050)],
      isEligible: (_) => true,
      statePolicy: statePolicy,
    );

    expect(snapshot, isNull);
  });

  test('returns null when route geometry is invalid', () {
    final snapshot = StopRuntimeSnapshotResolver.resolve(
      routePoints: const [
        RoutePoint(latitude: 31.0000, longitude: 35.0000),
      ],
      vehicleAlongMeters: 0,
      stops: [stop('stop', 35.0050)],
      isEligible: (_) => true,
      statePolicy: statePolicy,
    );

    expect(snapshot, isNull);
  });

  test(
    'uses stop order only as a tie-breaker inherited from NextStopResolver',
    () {
      final snapshot = StopRuntimeSnapshotResolver.resolve(
        routePoints: route,
        vehicleAlongMeters: 100,
        stops: [
          stop('later-order', 35.0050, order: 10),
          stop('earlier-order', 35.0050, order: 2),
        ],
        isEligible: (_) => true,
        statePolicy: statePolicy,
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.nextStop!.stop.id, 'earlier-order');
    },
  );

  test('does not require Firestore or runtime state to build the snapshot', () {
    final snapshot = StopRuntimeSnapshotResolver.resolve(
      routePoints: route,
      vehicleAlongMeters: 500,
      stops: [stop('stop', 35.0070)],
      isEligible: (_) => true,
      statePolicy: statePolicy,
    );

    expect(snapshot, isNotNull);
  });
}
