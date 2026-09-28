import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/eta_input.dart';
import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/accepted_eta_observation.dart';
import 'package:jordan_bus_tracker_new/services/eta_freshness_policy.dart';
import 'package:jordan_bus_tracker_new/services/eta_input_builder.dart';
import 'package:jordan_bus_tracker_new/services/next_stop_resolver.dart';
import 'package:jordan_bus_tracker_new/services/route_progress_calculator.dart';
import 'package:jordan_bus_tracker_new/services/stop_runtime_snapshot_resolver.dart';

void main() {
  final observedAt = DateTime.utc(2026, 9, 28, 20, 30);
  final evaluatedAt = observedAt.add(const Duration(seconds: 30));
  final freshnessPolicy = EtaFreshnessPolicy(
    maxAge: const Duration(minutes: 1),
  );

  RouteProgressProjection projection(double alongMeters) {
    return RouteProgressProjection(
      progress: 0.5,
      alongMeters: alongMeters,
      distanceToRouteMeters: 0,
      segmentIndex: 0,
      segmentT: 0.5,
    );
  }

  AcceptedEtaObservation observation({
    double alongMeters = 125,
    double speedMps = 8.5,
    DateTime? observedAtOverride,
  }) {
    return AcceptedEtaObservation(
      acceptedRouteProgress: projection(alongMeters),
      speedMps: speedMps,
      observedAt: observedAtOverride ?? observedAt,
    );
  }

  StopRuntimeSnapshot snapshotWithNextStop(double alongMeters) {
    final stop = PlannedRouteStopModel(
      id: 'stop-1',
      name: 'Stop 1',
      location: const GeoPoint(31, 35),
      order: 0,
    );

    final nextStop = ProjectedPlannedRouteStop(
      stop: stop,
      projection: projection(alongMeters),
    );

    return StopRuntimeSnapshot(
      eligibleProjectedStops: [nextStop],
      nextStop: nextStop,
      statesByStopId: const {},
    );
  }

  StopRuntimeSnapshot snapshotWithoutNextStop() {
    return StopRuntimeSnapshot(
      eligibleProjectedStops: const [],
      nextStop: null,
      statesByStopId: const {},
    );
  }

  test('builds EtaInput from a fresh observation and next stop', () {
    final result = EtaInputBuilder.build(
      observation: observation(),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNotNull);
    expect(result!.vehicleAlongMeters, 125);
    expect(result.targetAlongMeters, 640);
    expect(result.speedMps, 8.5);
    expect(result.observedAt, observedAt);
  });

  test('returns null for a stale observation', () {
    final staleObservedAt = evaluatedAt.subtract(
      const Duration(seconds: 61),
    );

    final result = EtaInputBuilder.build(
      observation: observation(observedAtOverride: staleObservedAt),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNull);
  });

  test('returns null for a future observation', () {
    final futureObservedAt = evaluatedAt.add(const Duration(seconds: 1));

    final result = EtaInputBuilder.build(
      observation: observation(observedAtOverride: futureObservedAt),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNull);
  });

  test('returns null when there is no next stop', () {
    final result = EtaInputBuilder.build(
      observation: observation(),
      stopRuntimeSnapshot: snapshotWithoutNextStop(),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNull);
  });

  test('takes vehicleAlongMeters exactly from the accepted observation', () {
    final result = EtaInputBuilder.build(
      observation: observation(alongMeters: 321.75),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNotNull);
    expect(result!.vehicleAlongMeters, 321.75);
  });

  test('takes targetAlongMeters exactly from the next stop projection', () {
    final result = EtaInputBuilder.build(
      observation: observation(),
      stopRuntimeSnapshot: snapshotWithNextStop(777.25),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNotNull);
    expect(result!.targetAlongMeters, 777.25);
  });

  test('takes speedMps exactly from the accepted observation', () {
    final result = EtaInputBuilder.build(
      observation: observation(speedMps: 3.25),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNotNull);
    expect(result!.speedMps, 3.25);
  });

  test('preserves observedAt from the accepted observation', () {
    final sourceObservedAt = DateTime.utc(2026, 9, 28, 21, 0, 12);

    final result = EtaInputBuilder.build(
      observation: observation(observedAtOverride: sourceObservedAt),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: sourceObservedAt.add(const Duration(seconds: 10)),
    );

    expect(result, isNotNull);
    expect(result!.observedAt, sourceObservedAt);
  });

  test('produces identical EtaInput values for identical inputs', () {
    final snapshot = snapshotWithNextStop(640);
    final sourceObservation = observation();

    final first = EtaInputBuilder.build(
      observation: sourceObservation,
      stopRuntimeSnapshot: snapshot,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );
    final second = EtaInputBuilder.build(
      observation: sourceObservation,
      stopRuntimeSnapshot: snapshot,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.vehicleAlongMeters, first!.vehicleAlongMeters);
    expect(second.targetAlongMeters, first.targetAlongMeters);
    expect(second.speedMps, first.speedMps);
    expect(second.observedAt, first.observedAt);
  });
}
