import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/services/stop_state_resolver.dart';

void main() {
  const totalRouteMeters = 10000.0;
  const policy = StopStatePolicy(
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

    test('classifies approaching above atStopRadius', () {
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

    test('classifies passed just beyond the negative radius boundary', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1020.001,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.passed);
    });

    test('classifies the same alongMeters as atStop', () {
      final state = StopStateResolver.resolve(
        vehicleAlongMeters: 1000,
        stopAlongMeters: 1000,
        totalRouteMeters: totalRouteMeters,
        policy: policy,
      );

      expect(state, StopState.atStop);
    });

    test('returns null for invalid vehicleAlongMeters', () {
      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: double.nan,
          stopAlongMeters: 1000,
          totalRouteMeters: totalRouteMeters,
          policy: policy,
        ),
        isNull,
      );

      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: -1,
          stopAlongMeters: 1000,
          totalRouteMeters: totalRouteMeters,
          policy: policy,
        ),
        isNull,
      );

      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: 10001,
          stopAlongMeters: 1000,
          totalRouteMeters: totalRouteMeters,
          policy: policy,
        ),
        isNull,
      );
    });

    test('returns null for invalid stopAlongMeters', () {
      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: 1000,
          stopAlongMeters: double.infinity,
          totalRouteMeters: totalRouteMeters,
          policy: policy,
        ),
        isNull,
      );

      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: 1000,
          stopAlongMeters: -1,
          totalRouteMeters: totalRouteMeters,
          policy: policy,
        ),
        isNull,
      );

      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: 1000,
          stopAlongMeters: 10001,
          totalRouteMeters: totalRouteMeters,
          policy: policy,
        ),
        isNull,
      );
    });

    test('returns null for an invalid route axis', () {
      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: 1000,
          stopAlongMeters: 1200,
          totalRouteMeters: 0,
          policy: policy,
        ),
        isNull,
      );

      expect(
        StopStateResolver.resolve(
          vehicleAlongMeters: 1000,
          stopAlongMeters: 1200,
          totalRouteMeters: double.nan,
          policy: policy,
        ),
        isNull,
      );
    });
  });

  group('StopStatePolicy', () {
    test('rejects a non-positive atStopRadius', () {
      expect(
        () => StopStatePolicy(
          atStopRadius: 0,
          approachingDistance: 200,
        ),
        throwsArgumentError,
      );

      expect(
        () => StopStatePolicy(
          atStopRadius: double.nan,
          approachingDistance: 200,
        ),
        throwsArgumentError,
      );
    });

    test('rejects approachingDistance that is not greater', () {
      expect(
        () => StopStatePolicy(
          atStopRadius: 20,
          approachingDistance: 20,
        ),
        throwsArgumentError,
      );

      expect(
        () => StopStatePolicy(
          atStopRadius: 20,
          approachingDistance: 19,
        ),
        throwsArgumentError,
      );

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
