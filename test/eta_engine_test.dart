import 'package:flutter_test/flutter_test.dart';

import '../lib/models/eta_input.dart';
import '../lib/models/eta_status.dart';
import '../lib/models/eta_unavailable_reason.dart';
import '../lib/services/eta_engine.dart';

void main() {
  final observedAt = DateTime(2026, 9, 28, 20, 30);

  EtaInput input({
    double vehicleAlongMeters = 100,
    double targetAlongMeters = 500,
    double speedMps = 10,
    DateTime? observedAtOverride,
  }) {
    return EtaInput(
      vehicleAlongMeters: vehicleAlongMeters,
      targetAlongMeters: targetAlongMeters,
      speedMps: speedMps,
      observedAt: observedAtOverride ?? observedAt,
    );
  }

  group('EtaEngine', () {
    test('calculates deterministic ETA for valid moving input', () {
      final result = EtaEngine.calculate(input());

      expect(result.status, EtaStatus.available);
      expect(result.distanceAheadMeters, 400);
      expect(result.etaSeconds, 40);
      expect(result.unavailableReason, isNull);
      expect(result.observedAt, observedAt);
    });

    test('preserves observedAt in an available result', () {
      final sourceTime = DateTime(2026, 9, 28, 21, 15, 30);

      final result = EtaEngine.calculate(
        input(observedAtOverride: sourceTime),
      );

      expect(result.observedAt, sourceTime);
    });

    test('returns targetNotAhead when the target is behind', () {
      final result = EtaEngine.calculate(
        input(vehicleAlongMeters: 500, targetAlongMeters: 400),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.targetNotAhead);
      expect(result.etaSeconds, isNull);
      expect(result.distanceAheadMeters, isNull);
      expect(result.observedAt, observedAt);
    });

    test('returns targetNotAhead when the target equals the vehicle position', () {
      final result = EtaEngine.calculate(
        input(vehicleAlongMeters: 500, targetAlongMeters: 500),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.targetNotAhead);
    });

    test('returns invalidVehicleProgress for negative vehicle progress', () {
      final result = EtaEngine.calculate(
        input(vehicleAlongMeters: -1),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(
        result.unavailableReason,
        EtaUnavailableReason.invalidVehicleProgress,
      );
    });

    test('returns invalidVehicleProgress for NaN vehicle progress', () {
      final result = EtaEngine.calculate(
        input(vehicleAlongMeters: double.nan),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(
        result.unavailableReason,
        EtaUnavailableReason.invalidVehicleProgress,
      );
    });

    test('returns invalidVehicleProgress for infinite vehicle progress', () {
      final result = EtaEngine.calculate(
        input(vehicleAlongMeters: double.infinity),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(
        result.unavailableReason,
        EtaUnavailableReason.invalidVehicleProgress,
      );
    });

    test('returns invalidTarget for negative target position', () {
      final result = EtaEngine.calculate(
        input(targetAlongMeters: -1),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.invalidTarget);
    });

    test('returns invalidTarget for NaN target position', () {
      final result = EtaEngine.calculate(
        input(targetAlongMeters: double.nan),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.invalidTarget);
    });

    test('returns invalidTarget for infinite target position', () {
      final result = EtaEngine.calculate(
        input(targetAlongMeters: double.infinity),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.invalidTarget);
    });

    test('returns nonPositiveSpeed for zero speed', () {
      final result = EtaEngine.calculate(
        input(speedMps: 0),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.nonPositiveSpeed);
    });

    test('returns nonPositiveSpeed for negative speed', () {
      final result = EtaEngine.calculate(
        input(speedMps: -1),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.nonPositiveSpeed);
    });

    test('returns invalidSpeed for NaN speed', () {
      final result = EtaEngine.calculate(
        input(speedMps: double.nan),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.invalidSpeed);
    });

    test('returns invalidSpeed for infinite speed', () {
      final result = EtaEngine.calculate(
        input(speedMps: double.infinity),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.invalidSpeed);
    });

    test('preserves observedAt when ETA is unavailable', () {
      final sourceTime = DateTime(2026, 9, 28, 22, 5);

      final result = EtaEngine.calculate(
        input(
          speedMps: 0,
          observedAtOverride: sourceTime,
        ),
      );

      expect(result.status, EtaStatus.unavailable);
      expect(result.observedAt, sourceTime);
      expect(result.etaSeconds, isNull);
      expect(result.distanceAheadMeters, isNull);
    });

    test('returns the same result for repeated identical inputs', () {
      final first = EtaEngine.calculate(input());
      final second = EtaEngine.calculate(input());

      expect(second.status, first.status);
      expect(second.distanceAheadMeters, first.distanceAheadMeters);
      expect(second.etaSeconds, first.etaSeconds);
      expect(second.observedAt, first.observedAt);
      expect(second.unavailableReason, first.unavailableReason);
    });
  });
}
