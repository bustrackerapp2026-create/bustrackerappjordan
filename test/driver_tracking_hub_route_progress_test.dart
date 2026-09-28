import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'package:jordan_bus_tracker_new/driver/services/driver_tracking_hub.dart';
import 'package:jordan_bus_tracker_new/services/stop_state_resolver.dart';
import 'package:jordan_bus_tracker_new/services/stop_runtime_policy.dart';
import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';

void main() {
  final hub = DriverTrackingHub.instance;

  RoutePoint point(double latitude, double longitude) =>
      RoutePoint(latitude: latitude, longitude: longitude);

  final route = [
    point(31.0000, 35.0000),
    point(31.0000, 35.0050),
    point(31.0000, 35.0100),
  ];

  geo.Position gps(
    double latitude,
    double longitude, {
    DateTime? timestamp,
    double speed = 0.0,
  }) => geo.Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp ?? DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: speed,
        speedAccuracy: 1.0,
      );


  PlannedRouteStopModel stop(String id, double longitude) {
    return PlannedRouteStopModel(
      id: id,
      name: id,
      location: GeoPoint(31.0000, longitude),
      order: 0,
    );
  }

  PlannedRouteStopModel offRouteStop(
    String id,
    double latitude,
    double longitude,
  ) {
    return PlannedRouteStopModel(
      id: id,
      name: id,
      location: GeoPoint(latitude, longitude),
      order: 0,
    );
  }

  setUp(() {
    hub.clearActiveVehicleTrip();
  });

  tearDown(() {
    hub.clearActiveVehicleTrip();
  });

  group('DriverTrackingHub RouteProgress integration', () {
    test('binds route geometry and accepts the first GPS projection', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );

      final result = hub.updateRouteProgress(gps(31.0000, 35.0000));

      expect(result, isNotNull);
      expect(result!.progress, closeTo(0.0, 0.0005));
      expect(hub.activeRouteProgress, same(result));
    });

    test('keeps RouteProgress monotonic across forward GPS samples', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );

      final start = hub.updateRouteProgress(
        gps(31.0000, 35.0000, timestamp: DateTime.utc(2026, 1, 1), speed: 40.0),
      );
      final midpoint = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0025,
          timestamp: DateTime.utc(2026, 1, 1, 0, 0, 10),
          speed: 40.0,
        ),
      );
      final later = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0040,
          timestamp: DateTime.utc(2026, 1, 1, 0, 0, 15),
          speed: 40.0,
        ),
      );

      expect(start, isNotNull);
      expect(midpoint, isNotNull);
      expect(later, isNotNull);
      expect(midpoint!.progress, greaterThan(start!.progress));
      expect(later!.progress, greaterThan(midpoint.progress));
    });

    test('preserves accepted progress when GPS jitters backwards', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );

      final midpoint = hub.updateRouteProgress(gps(31.0000, 35.0100));
      final jitter = hub.updateRouteProgress(gps(31.0000, 35.0095));

      expect(midpoint, isNotNull);
      expect(jitter, isNotNull);
      expect(jitter!.progress, closeTo(midpoint!.progress, 0.0001));
    });

    test('does not replace ETA observation when a GPS sample is rejected', () {
      hub.setActiveVehicleTrip(
        'trip-eta-rejected',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );

      final timeA = DateTime.utc(2026, 9, 28, 20, 0, 0);
      final acceptedA = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0025,
          timestamp: timeA,
          speed: 8.0,
        ),
      );
      final observationA = hub.activeEtaObservation;

      final timeB = timeA.add(const Duration(seconds: 5));
      final rejectedB = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0100,
          timestamp: timeB,
          speed: 42.0,
        ),
      );

      expect(acceptedA, isNotNull);
      expect(observationA, isNotNull);
      expect(rejectedB, same(acceptedA));
      expect(hub.activeEtaObservation, same(observationA));
      expect(observationA!.acceptedRouteProgress, same(acceptedA));
      expect(observationA.speedMps, 8.0);
      expect(observationA.observedAt, timeA);
      expect(hub.activeEtaObservation!.speedMps, isNot(42.0));
      expect(hub.activeEtaObservation!.observedAt, isNot(timeB));
    });

    test('updates ETA observation for an accepted backward-jitter sample', () {
      hub.setActiveVehicleTrip(
        'trip-eta-jitter',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );

      final timeA = DateTime.utc(2026, 9, 28, 20, 10, 0);
      final acceptedA = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0050,
          timestamp: timeA,
          speed: 10.0,
        ),
      );
      final observationA = hub.activeEtaObservation;

      final timeB = timeA.add(const Duration(seconds: 5));
      final acceptedB = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0045,
          timestamp: timeB,
          speed: 6.5,
        ),
      );
      final observationB = hub.activeEtaObservation;

      expect(acceptedA, isNotNull);
      expect(acceptedB, isNotNull);
      expect(acceptedB, isNot(same(acceptedA)));
      expect(acceptedB!.alongMeters, closeTo(acceptedA!.alongMeters, 0.1));
      expect(observationA, isNotNull);
      expect(observationB, isNotNull);
      expect(observationB, isNot(same(observationA)));
      expect(observationB!.acceptedRouteProgress, same(acceptedB));
      expect(observationB.speedMps, 6.5);
      expect(observationB.observedAt, timeB);
    });

    test('starts a new VehicleTrip with fresh RouteProgress state', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );
      hub.updateRouteProgress(gps(31.0000, 35.0100));

      hub.setActiveVehicleTrip(
        'trip-2',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );

      expect(hub.activeRouteProgress, isNull);
      final newTripStart =
          hub.updateRouteProgress(gps(31.0000, 35.0000));

      expect(newTripStart, isNotNull);
      expect(newTripStart!.progress, closeTo(0.0, 0.0005));
    });

    test('restores saved progress before the next GPS sample', () {
      hub.setActiveVehicleTrip(
        'trip-restore',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
        savedRouteProgress: 0.5,
      );

      expect(hub.activeRouteProgress, isNotNull);
      expect(hub.activeRouteProgress!.progress, closeTo(0.5, 0.0001));

      final behindMidpoint =
          hub.updateRouteProgress(gps(31.0000, 35.0040));

      expect(behindMidpoint, isNotNull);
      expect(behindMidpoint!.progress, closeTo(0.5, 0.001));
    });

    test('does not reset progress when the same trip is rebound', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );
      hub.updateRouteProgress(
        gps(31.0000, 35.0050, timestamp: DateTime.utc(2026, 1, 1), speed: 10.0),
      );

      final reboundRoute = List<RoutePoint>.from(route);
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: reboundRoute,
      );

      expect(hub.activeRouteProgress, isNotNull);
      expect(hub.activeRouteProgress!.progress, closeTo(0.5, 0.001));

      final later = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0055,
          timestamp: DateTime.utc(2026, 1, 1, 0, 0, 5),
          speed: 10.0,
        ),
      );

      expect(later, isNotNull);
      expect(later!.progress, greaterThan(0.5));
      expect(later.progress, closeTo(0.55, 0.01));
    });

    test('resets progress when the same trip changes routeId', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );
      hub.updateRouteProgress(gps(31.0000, 35.0100));

      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-b',
        direction: 'go',
        routePoints: route,
      );

      expect(hub.activeRouteProgress, isNull);

      final newRouteStart =
          hub.updateRouteProgress(gps(31.0000, 35.0000));

      expect(newRouteStart, isNotNull);
      expect(newRouteStart!.progress, closeTo(0.0, 0.0005));
    });


    test('derives a stop runtime snapshot from the accepted RouteProgress', () {
      hub.setActiveVehicleTrip(
        'trip-runtime',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
        stopRuntimePolicy: StopRuntimePolicy.production(),
      );
      hub.setActiveVehicleTripStops(
        tripId: 'trip-runtime',
        routeId: 'route-a',
        stops: [
          stop('stop-1', 35.0040),
          stop('stop-2', 35.0080),
        ],
      );

      final progress = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0025,
          timestamp: DateTime.utc(2026, 9, 28, 20, 0, 0),
          speed: 10.0,
        ),
      );
      expect(progress, isNotNull);

      final snapshot = hub.activeStopRuntimeSnapshot;

      expect(snapshot, isNotNull);
      expect(hub.activeStopRuntimeSnapshot, same(snapshot));
      expect(snapshot!.nextStop!.stop.id, 'stop-1');
      expect(snapshot.statesByStopId['stop-1'], StopState.approaching);
    });

    test('uses the centrally bound production eligibility policy', () {
      hub.setActiveVehicleTrip(
        'trip-runtime-policy',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
        stopRuntimePolicy: StopRuntimePolicy.production(),
      );
      hub.setActiveVehicleTripStops(
        tripId: 'trip-runtime-policy',
        routeId: 'route-a',
        stops: [
          stop('eligible', 35.0040),
          offRouteStop('ineligible', 31.0010, 35.0060),
        ],
      );
      final progress = hub.updateRouteProgress(
        gps(
          31.0000,
          35.0025,
          timestamp: DateTime.utc(2026, 9, 28, 20, 0, 0),
          speed: 10.0,
        ),
      );
      expect(progress, isNotNull);

      final snapshot = hub.activeStopRuntimeSnapshot;

      expect(snapshot, isNotNull);
      expect(
        snapshot!.eligibleProjectedStops.map((candidate) => candidate.stop.id),
        ['eligible'],
      );
      expect(snapshot.nextStop!.stop.id, 'eligible');
      expect(snapshot.statesByStopId.containsKey('ineligible'), isFalse);
    });

    test('returns null when no accepted RouteProgress exists', () {
      hub.setActiveVehicleTrip(
        'trip-runtime-no-progress',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
        stopRuntimePolicy: StopRuntimePolicy.production(),
      );
      hub.setActiveVehicleTripStops(
        tripId: 'trip-runtime-no-progress',
        routeId: 'route-a',
        stops: [stop('stop', 35.0040)],
      );

      final snapshot = hub.refreshActiveStopRuntimeSnapshot();

      expect(snapshot, isNull);
      expect(hub.activeStopRuntimeSnapshot, isNull);
    });

    test('clears the derived snapshot when the route binding changes', () {
      hub.setActiveVehicleTrip(
        'trip-runtime-clear',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
        stopRuntimePolicy: StopRuntimePolicy.production(),
      );
      hub.setActiveVehicleTripStops(
        tripId: 'trip-runtime-clear',
        routeId: 'route-a',
        stops: [stop('stop', 35.0040)],
      );
      hub.updateRouteProgress(
        gps(
          31.0000,
          35.0025,
          timestamp: DateTime.utc(2026, 9, 28, 20, 0, 0),
          speed: 10.0,
        ),
      );
      expect(hub.activeStopRuntimeSnapshot, isNotNull);

      hub.setActiveVehicleTrip(
        'trip-runtime-clear',
        routeId: 'route-b',
        direction: 'go',
        routePoints: route,
      );

      expect(hub.activeStopRuntimeSnapshot, isNull);
    });

    test('clearActiveVehicleTrip clears route geometry and progress state', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );
      hub.updateRouteProgress(gps(31.0000, 35.0100));

      hub.clearActiveVehicleTrip();

      expect(hub.activeRouteProgress, isNull);
      expect(
        hub.updateRouteProgress(gps(31.0000, 35.0120)),
        isNull,
      );
    });

    test('stores a loaded fixed-stop snapshot for the active trip', () {
      hub.setActiveVehicleTrip(
        'trip-stops',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
        stopRuntimePolicy: StopRuntimePolicy.production(),
      );

      hub.updateRouteProgress(
        gps(
          31.0000,
          35.0025,
          timestamp: DateTime.utc(2026, 9, 28, 20, 0, 0),
          speed: 10.0,
        ),
      );

      final stops = [
        stop('stop-1', 35.0030),
        stop('stop-2', 35.0070),
      ];

      hub.setActiveVehicleTripStops(
        tripId: 'trip-stops',
        routeId: 'route-a',
        stops: stops,
      );

      expect(hub.activeVehicleTripStops, isNotNull);
      expect(
        hub.activeVehicleTripStops!.map((item) => item.id),
        ['stop-1', 'stop-2'],
      );
      expect(hub.activeStopRuntimeSnapshot, isNotNull);
      expect(hub.activeStopRuntimeSnapshot!.nextStop!.stop.id, 'stop-1');
    });

    test('ignores a stop snapshot that no longer matches the active trip binding', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );

      hub.setActiveVehicleTripStops(
        tripId: 'trip-other',
        routeId: 'route-a',
        stops: [stop('stale', 35.0030)],
      );

      expect(hub.activeVehicleTripStops, isNull);
    });

    test('clears fixed-stop data when the active trip binding changes or clears', () {
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: route,
      );
      hub.setActiveVehicleTripStops(
        tripId: 'trip-1',
        routeId: 'route-a',
        stops: [stop('stop-1', 35.0030)],
      );

      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-b',
        direction: 'go',
        routePoints: route,
      );
      expect(hub.activeVehicleTripStops, isNull);

      hub.setActiveVehicleTripStops(
        tripId: 'trip-1',
        routeId: 'route-b',
        stops: [stop('stop-2', 35.0070)],
      );
      expect(hub.activeVehicleTripStops, isNotNull);

      hub.clearActiveVehicleTrip();
      expect(hub.activeVehicleTripStops, isNull);
    });

  });
}
