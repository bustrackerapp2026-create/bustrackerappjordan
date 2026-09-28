import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/services/eta_freshness_policy.dart';

void main() {
  group('EtaFreshnessPolicy', () {
    test('returns fresh when observedAt equals evaluatedAt', () {
      final evaluatedAt = DateTime(2026, 9, 28, 20, 30);
      final policy = EtaFreshnessPolicy(maxAge: const Duration.zero);

      final result = policy.evaluate(
        observedAt: evaluatedAt,
        evaluatedAt: evaluatedAt,
      );

      expect(result, EtaFreshnessStatus.fresh);
    });

    test('returns fresh when age is below maxAge', () {
      final observedAt = DateTime(2026, 9, 28, 20, 30);
      final maxAge = const Duration(minutes: 1);
      final evaluatedAt = observedAt.add(
        maxAge - const Duration(microseconds: 1),
      );
      final policy = EtaFreshnessPolicy(maxAge: maxAge);

      final result = policy.evaluate(
        observedAt: observedAt,
        evaluatedAt: evaluatedAt,
      );

      expect(result, EtaFreshnessStatus.fresh);
    });

    test('returns fresh when age equals maxAge', () {
      final observedAt = DateTime(2026, 9, 28, 20, 30);
      final maxAge = const Duration(minutes: 1);
      final evaluatedAt = observedAt.add(maxAge);
      final policy = EtaFreshnessPolicy(maxAge: maxAge);

      final result = policy.evaluate(
        observedAt: observedAt,
        evaluatedAt: evaluatedAt,
      );

      expect(result, EtaFreshnessStatus.fresh);
    });

    test('returns stale when age is above maxAge', () {
      final observedAt = DateTime(2026, 9, 28, 20, 30);
      final maxAge = const Duration(minutes: 1);
      final evaluatedAt = observedAt.add(
        maxAge + const Duration(microseconds: 1),
      );
      final policy = EtaFreshnessPolicy(maxAge: maxAge);

      final result = policy.evaluate(
        observedAt: observedAt,
        evaluatedAt: evaluatedAt,
      );

      expect(result, EtaFreshnessStatus.stale);
    });

    test('returns future when observedAt is later than evaluatedAt', () {
      final evaluatedAt = DateTime(2026, 9, 28, 20, 30);
      final observedAt = evaluatedAt.add(const Duration(microseconds: 1));
      final policy = EtaFreshnessPolicy(
        maxAge: const Duration(minutes: 1),
      );

      final result = policy.evaluate(
        observedAt: observedAt,
        evaluatedAt: evaluatedAt,
      );

      expect(result, EtaFreshnessStatus.future);
    });

    test('returns the same result for repeated identical inputs', () {
      final observedAt = DateTime(2026, 9, 28, 20, 30);
      final evaluatedAt = observedAt.add(const Duration(minutes: 1));
      final policy = EtaFreshnessPolicy(maxAge: const Duration(minutes: 1));

      final first = policy.evaluate(
        observedAt: observedAt,
        evaluatedAt: evaluatedAt,
      );
      final second = policy.evaluate(
        observedAt: observedAt,
        evaluatedAt: evaluatedAt,
      );

      expect(second, first);
    });
  });
}
