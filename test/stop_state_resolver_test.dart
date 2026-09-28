import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/services/stop_state_resolver.dart';

void main() {
  const totalRouteMeters = 10000.0;
  final policy = StopStatePolicy(
    atStopRadius: 20,
    approachingDistance: 200,
  );

  group('StopStateResolver', () {
    test('classifies upcoming when delta is beyond approachingDistance', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: 1200.001,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.upcoming);
    });

    test('classifies approaching at approachingDistance boundary', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: 1200,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.approaching);
    });

    test('classifies approaching just above atStopRadius', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: 1020.001,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.approaching);
    });

    test('classifies atStop at positive radius boundary', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: 1020,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.atStop);
    });

    test('classifies atStop at negative radius boundary', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1020,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.atStop);
    });

    test('classifies passed just beyond negative radius', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1020.001,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.passed);
    });

    test('classifies same along position as atStop', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.atStop);
    });

    test('returns null for NaN vehicle position', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: double.nan,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, isNull);
    });

    test('returns null for negative vehicle position', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: -0.001,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, isNull);
    });

    test('returns null for vehicle position above route axis', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: totalRouteMeters + 0.001,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, isNull);
    });

    test('returns null for infinite stop position', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: double.infinity,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, isNull);
    });

    test('returns null for negative stop position', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: -0.001,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, isNull);
    });

    test('returns null for stop position above route axis', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: totalRouteMeters + 0.001,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, isNull);
    });

    test('returns null for nonpositive route length', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 100,
        stopAlongMeters: 200,
        totalRouteMeters: 0,
        policy: policy,
      );

      expect(state, isNull);
    });

    test('returns null for nonfinite route length', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 100,
        stopAlongMeters: 200,
        totalRouteMeters: double.nan,
        policy: policy,
      );

      expect(state, isNull);
    });
  });

  group('StopStatePolicy', () {
    test('rejects zero atStopRadius', () {
      expect(
        () => StopStatePolicy(
          atStopRadius: 0,
          approachingDistance: 200,
        ),
        throwsArgumentError,
      );
    });

    test('rejects NaN atStopRadius', () {
      expect(
        () => StopStatePolicy(
          atStopRadius: double.nan,
          approachingDistance: 200,
        ),
        throwsArgumentError,
      );
    });

    test('rejects approachingDistance equal to atStopRadius', () {
      expect(
        () => StopStatePolicy(
          atStopRadius: 20,
          approachingDistance: 20,
        ),
        throwsArgumentError,
      );
    });

    test('rejects approachingDistance below atStopRadius', () {
      expect(
        () => StopStatePolicy(
          atStopRadius: 20,
          approachingDistance: 19,
        ),
        throwsArgumentError,
      );
    });

    test('rejects infinite approachingDistance', () {
      expect(
        () => StopStatePolicy(
          atStopRadius: 20,
          approachingDistance: double.infinity,
        ),
        throwsArgumentError,
      );
    });
  });
}
