import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/services/vehicle_location_freshness_policy.dart';

void main() {
  final evaluatedAt = DateTime.utc(2026, 10, 2, 20, 0);

  test('missing timestamp is missing', () {
    const policy = VehicleLocationFreshnessPolicy(
      maxAge: Duration(minutes: 1),
    );

    expect(
      policy.evaluate(
        lastLocationAt: null,
        evaluatedAt: evaluatedAt,
      ),
      VehicleLocationFreshnessStatus.missing,
    );
  });

  test('timestamp at maxAge boundary is fresh', () {
    const policy = VehicleLocationFreshnessPolicy(
      maxAge: Duration(minutes: 1),
    );

    expect(
      policy.evaluate(
        lastLocationAt: evaluatedAt.subtract(
          const Duration(minutes: 1),
        ),
        evaluatedAt: evaluatedAt,
      ),
      VehicleLocationFreshnessStatus.fresh,
    );
  });

  test('timestamp older than maxAge is stale', () {
    const policy = VehicleLocationFreshnessPolicy(
      maxAge: Duration(minutes: 1),
    );

    expect(
      policy.evaluate(
        lastLocationAt: evaluatedAt.subtract(
          const Duration(minutes: 1, seconds: 1),
        ),
        evaluatedAt: evaluatedAt,
      ),
      VehicleLocationFreshnessStatus.stale,
    );
  });

  test('future timestamp is future', () {
    const policy = VehicleLocationFreshnessPolicy(
      maxAge: Duration(minutes: 1),
    );

    expect(
      policy.evaluate(
        lastLocationAt: evaluatedAt.add(const Duration(seconds: 1)),
        evaluatedAt: evaluatedAt,
      ),
      VehicleLocationFreshnessStatus.future,
    );
  });

  test('evaluation is deterministic for identical inputs', () {
    const policy = VehicleLocationFreshnessPolicy(
      maxAge: Duration(minutes: 1),
    );
    final observedAt = evaluatedAt.subtract(const Duration(seconds: 30));

    expect(
      policy.evaluate(
        lastLocationAt: observedAt,
        evaluatedAt: evaluatedAt,
      ),
      policy.evaluate(
        lastLocationAt: observedAt,
        evaluatedAt: evaluatedAt,
      ),
    );
  });
}
