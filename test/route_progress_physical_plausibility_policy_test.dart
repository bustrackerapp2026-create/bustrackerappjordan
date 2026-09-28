import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/services/route_progress_physical_plausibility_policy.dart';

void main() {
  final base = DateTime(2026, 9, 28, 4, 0, 0);
  DateTime at(int seconds) => base.add(Duration(seconds: seconds));

  RouteProgressPhysicalPlausibilityConstrained constrained(
    RouteProgressPhysicalPlausibilityResult result,
  ) {
    expect(
      result,
      isA<RouteProgressPhysicalPlausibilityConstrained>(),
    );
    return result as RouteProgressPhysicalPlausibilityConstrained;
  }

  group('RouteProgressPhysicalPlausibilityPolicy', () {
    test('calculates a time-and-speed based allowance', () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(5),
        previousValidSpeedMetersPerSecond: 4.0,
        currentValidSpeedMetersPerSecond: 6.0,
      ));

      expect(
        result.maxAllowedForwardDistanceMeters,
        closeTo(65.0, 0.0001),
      );
    });

    test('same timestamp is constrained to zero forward distance', () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(0),
        previousValidSpeedMetersPerSecond: 100.0,
        currentValidSpeedMetersPerSecond: 100.0,
      ));

      expect(result.maxAllowedForwardDistanceMeters, 0.0);
    });

    test('timestamp regression makes the physical gate unavailable', () {
      final result = RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(5),
        currentTimestamp: at(4),
        previousValidSpeedMetersPerSecond: 10.0,
        currentValidSpeedMetersPerSecond: 10.0,
      );

      expect(
        result,
        isA<RouteProgressPhysicalPlausibilityUnavailable>(),
      );
    });

    test('missing timestamps make the physical gate unavailable', () {
      final result = RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: null,
        currentTimestamp: at(5),
        previousValidSpeedMetersPerSecond: 10.0,
        currentValidSpeedMetersPerSecond: 10.0,
      );

      expect(
        result,
        isA<RouteProgressPhysicalPlausibilityUnavailable>(),
      );
    });

    test('long timestamp gaps make the physical gate unavailable', () {
      final result = RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(31),
        previousValidSpeedMetersPerSecond: 10.0,
        currentValidSpeedMetersPerSecond: 10.0,
      );

      expect(
        result,
        isA<RouteProgressPhysicalPlausibilityUnavailable>(),
      );
    });

    test('uses current valid speed before previous accepted speed', () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(5),
        previousValidSpeedMetersPerSecond: 2.0,
        currentValidSpeedMetersPerSecond: 4.0,
      ));

      expect(
        result.maxAllowedForwardDistanceMeters,
        closeTo(50.0, 0.0001),
      );
    });

    test('falls back to previous valid accepted speed', () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(5),
        previousValidSpeedMetersPerSecond: 4.0,
        currentValidSpeedMetersPerSecond: double.nan,
      ));

      expect(
        result.maxAllowedForwardDistanceMeters,
        closeTo(50.0, 0.0001),
      );
    });

    test('no valid speed makes the physical gate unavailable', () {
      final result = RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(5),
        previousValidSpeedMetersPerSecond: -1.0,
        currentValidSpeedMetersPerSecond: double.infinity,
      );

      expect(
        result,
        isA<RouteProgressPhysicalPlausibilityUnavailable>(),
      );
    });

    test('zero speed remains valid for stops and allows only the safety margin',
        () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(5),
        previousValidSpeedMetersPerSecond: 0.0,
        currentValidSpeedMetersPerSecond: 0.0,
      ));

      expect(result.maxAllowedForwardDistanceMeters, 20.0);
    });

    test('caps the physical allowance at the 300m hard limit', () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(30),
        previousValidSpeedMetersPerSecond: 20.0,
        currentValidSpeedMetersPerSecond: 20.0,
      ));

      expect(
        result.maxAllowedForwardDistanceMeters,
        RouteProgressPhysicalPlausibilityPolicy.hardCapMeters,
      );
    });

    test('30-second boundary remains constrained',
        () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(30),
        previousValidSpeedMetersPerSecond: 1.0,
        currentValidSpeedMetersPerSecond: 1.0,
      ));

      expect(
        result.maxAllowedForwardDistanceMeters,
        closeTo(65.0, 0.0001),
      );
    });

    test('current invalid negative speed falls back to previous valid speed',
        () {
      final result =
          constrained(RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: at(0),
        currentTimestamp: at(5),
        previousValidSpeedMetersPerSecond: 3.0,
        currentValidSpeedMetersPerSecond: -2.0,
      ));

      expect(
        result.maxAllowedForwardDistanceMeters,
        closeTo(42.5, 0.0001),
      );
    });
  });
}
