import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/planned_route_stop_projection.dart';
import 'package:jordan_bus_tracker_new/services/route_plan/route_plan_geometry.dart';

void main() {
  group('PlannedRouteStopProjection', () {
    test('projects a stop on a single segment', () {
      final route = _straightRoute();
      final stop = _stopAt(31.0, 35.005);

      final result = PlannedRouteStopProjection.project(
        stop: stop,
        routePoints: route,
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 0);
      expect(result.segmentT, closeTo(0.5, 1e-9));
      expect(
        result.alongMeters,
        closeTo(
          RoutePlanGeometry.distanceMeters(
            31.0,
            35.0,
            31.0,
            35.005,
          ),
          0.01,
        ),
      );
      expect(result.distanceToRouteMeters, closeTo(0, 1e-9));
    });

    test('accumulates alongMeters across multiple segments', () {
      final route = <RoutePoint>[
        const RoutePoint(latitude: 31.0, longitude: 35.0),
        const RoutePoint(latitude: 31.0, longitude: 35.01),
        const RoutePoint(latitude: 31.005, longitude: 35.01),
      ];
      final firstLength = RoutePlanGeometry.distanceMeters(
        31.0,
        35.0,
        31.0,
        35.01,
      );
      final secondHalf = RoutePlanGeometry.distanceMeters(
        31.0,
        35.01,
        31.0025,
        35.01,
      );
      final stop = _stopAt(31.0025, 35.01);

      final result = PlannedRouteStopProjection.project(
        stop: stop,
        routePoints: route,
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 1);
      expect(result.segmentT, closeTo(0.5, 1e-9));
      expect(result.alongMeters, closeTo(firstLength + secondHalf, 0.01));
      expect(result.distanceToRouteMeters, closeTo(0, 1e-9));
    });

    test('projects a stop at the route start to alongMeters zero', () {
      final result = PlannedRouteStopProjection.project(
        stop: _stopAt(31.0, 35.0),
        routePoints: _straightRoute(),
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 0);
      expect(result.segmentT, 0);
      expect(result.alongMeters, 0);
      expect(result.distanceToRouteMeters, closeTo(0, 1e-9));
    });

    test('projects a stop at the route end to total route length', () {
      final route = _straightRoute();

      final result = PlannedRouteStopProjection.project(
        stop: _stopAt(31.0, 35.01),
        routePoints: route,
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 0);
      expect(result.segmentT, 1);
      expect(
        result.alongMeters,
        closeTo(RoutePlanGeometry.totalDistanceMeters(route), 0.01),
      );
      expect(result.distanceToRouteMeters, closeTo(0, 1e-9));
    });

    test('projects an off-route stop without rejecting it', () {
      final result = PlannedRouteStopProjection.project(
        stop: _stopAt(31.0005, 35.005),
        routePoints: _straightRoute(),
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 0);
      expect(result.segmentT, closeTo(0.5, 1e-9));
      expect(result.distanceToRouteMeters, greaterThan(0));
    });

    test('reuses repeated-point primitive behavior', () {
      final route = <RoutePoint>[
        const RoutePoint(latitude: 31.0, longitude: 35.0),
        const RoutePoint(latitude: 31.0, longitude: 35.0),
        const RoutePoint(latitude: 31.0, longitude: 35.01),
      ];
      final realSegmentLength = RoutePlanGeometry.distanceMeters(
        31.0,
        35.0,
        31.0,
        35.01,
      );

      final result = PlannedRouteStopProjection.project(
        stop: _stopAt(31.0, 35.005),
        routePoints: route,
      );

      expect(result, isNotNull);
      expect(result!.segmentIndex, 1);
      expect(result.segmentT, closeTo(0.5, 1e-9));
      expect(result.alongMeters, closeTo(realSegmentLength * 0.5, 0.01));
      expect(result.distanceToRouteMeters, closeTo(0, 1e-9));
    });

    test('returns null for a route with fewer than two points', () {
      final result = PlannedRouteStopProjection.project(
        stop: _stopAt(31.0, 35.0),
        routePoints: const [
          RoutePoint(latitude: 31.0, longitude: 35.0),
        ],
      );

      expect(result, isNull);
    });

    test('returns null for a route with zero geometric length', () {
      final result = PlannedRouteStopProjection.project(
        stop: _stopAt(31.0, 35.0),
        routePoints: const [
          RoutePoint(latitude: 31.0, longitude: 35.0),
          RoutePoint(latitude: 31.0, longitude: 35.0),
        ],
      );

      expect(result, isNull);
    });
  });
}

PlannedRouteStopModel _stopAt(double latitude, double longitude) {
  return PlannedRouteStopModel(
    id: 'test-stop',
    name: 'Test Stop',
    location: GeoPoint(latitude, longitude),
    order: 0,
  );
}

List<RoutePoint> _straightRoute() {
  return const <RoutePoint>[
    RoutePoint(latitude: 31.0, longitude: 35.0),
    RoutePoint(latitude: 31.0, longitude: 35.01),
  ];
}
