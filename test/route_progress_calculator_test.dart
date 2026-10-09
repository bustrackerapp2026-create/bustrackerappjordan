import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/route_progress_calculator.dart';

void main() {
  RoutePoint point(double latitude, double longitude) =>
      RoutePoint(latitude: latitude, longitude: longitude);

  final straightRoute = [
    point(31.0000, 35.0000),
    point(31.0000, 35.0100),
    point(31.0000, 35.0200),
  ];

  group('RouteProgressCalculator', () {
    test('projects the start near 0.00', () {
      final result = RouteProgressCalculator.project(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
      );

      expect(result, isNotNull);
      expect(result!.progress, closeTo(0.0, 0.0005));
      expect(result.distanceToRouteMeters, closeTo(0.0, 0.1));
    });

    test('projects the middle near 0.50', () {
      final result = RouteProgressCalculator.project(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0100,
      );

      expect(result, isNotNull);
      expect(result!.progress, closeTo(0.5, 0.001));
      expect(result.distanceToRouteMeters, closeTo(0.0, 0.1));
    });

    test('projects the end near 1.00', () {
      final result = RouteProgressCalculator.project(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0200,
      );

      expect(result, isNotNull);
      expect(result!.progress, closeTo(1.0, 0.0005));
      expect(result.distanceToRouteMeters, closeTo(0.0, 0.1));
    });

    test('keeps progress stable for a small lateral GPS offset', () {
      final result = RouteProgressCalculator.project(
        routePoints: straightRoute,
        latitude: 31.0005,
        longitude: 35.0100,
      );

      expect(result, isNotNull);
      expect(result!.progress, closeTo(0.5, 0.001));
      expect(result.distanceToRouteMeters, greaterThan(40));
      expect(result.distanceToRouteMeters, lessThan(70));
    });

    test('rejects a position too far from the route', () {
      final result = RouteProgressCalculator.project(
        routePoints: straightRoute,
        latitude: 31.0100,
        longitude: 35.0100,
      );

      expect(result, isNull);
    });

    test('accuracy can expand projection tolerance up to the fixed cap', () {
      final tooFarForDefault = RouteProgressCalculator.project(
        routePoints: straightRoute,
        latitude: 31.0015,
        longitude: 35.0100,
      );
      final acceptedWithAccuracy = RouteProgressCalculator.project(
        routePoints: straightRoute,
        latitude: 31.0015,
        longitude: 35.0100,
        accuracy: 100,
      );

      expect(tooFarForDefault, isNull);
      expect(acceptedWithAccuracy, isNotNull);
    });

    test('rejects invalid route coordinates', () {
      final result = RouteProgressCalculator.project(
        routePoints: [
          point(31.0000, 35.0000),
          point(double.nan, 35.0100),
        ],
        latitude: 31.0000,
        longitude: 35.0050,
      );

      expect(result, isNull);
    });

    test('rejects a zero-length route', () {
      final result = RouteProgressCalculator.project(
        routePoints: [
          point(31.0000, 35.0000),
          point(31.0000, 35.0000),
        ],
        latitude: 31.0000,
        longitude: 35.0000,
      );

      expect(result, isNull);
    });
  });
}
