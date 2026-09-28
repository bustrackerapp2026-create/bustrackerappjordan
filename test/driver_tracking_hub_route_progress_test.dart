import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'package:jordan_bus_tracker_new/driver/services/driver_tracking_hub.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';

void main() {
  final hub = DriverTrackingHub.instance;

  RoutePoint point(double latitude, double longitude) =>
      RoutePoint(latitude: latitude, longitude: longitude);

  final route = [
    point(31.0000, 35.0000),
    point(31.0000, 35.0100),
    point(31.0000, 35.0200),
  ];

  geo.Position gps(double latitude, double longitude) => geo.Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

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

      final start = hub.updateRouteProgress(gps(31.0000, 35.0000));
      final midpoint = hub.updateRouteProgress(gps(31.0000, 35.0100));
      final later = hub.updateRouteProgress(gps(31.0000, 35.0140));

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
      hub.updateRouteProgress(gps(31.0000, 35.0100));

      final reboundRoute = List<RoutePoint>.from(route);
      hub.setActiveVehicleTrip(
        'trip-1',
        routeId: 'route-a',
        direction: 'go',
        routePoints: reboundRoute,
      );

      expect(hub.activeRouteProgress, isNotNull);
      expect(hub.activeRouteProgress!.progress, closeTo(0.5, 0.001));

      final later =
          hub.updateRouteProgress(gps(31.0000, 35.0110));

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
  });
}
