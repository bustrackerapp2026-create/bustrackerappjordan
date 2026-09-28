import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/eta_status.dart';
import 'package:jordan_bus_tracker_new/models/eta_unavailable_reason.dart';
import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';
import 'package:jordan_bus_tracker_new/services/accepted_eta_observation.dart';
import 'package:jordan_bus_tracker_new/services/eta_freshness_policy.dart';
import 'package:jordan_bus_tracker_new/services/eta_runtime_invocation.dart';
import 'package:jordan_bus_tracker_new/services/next_stop_resolver.dart';
import 'package:jordan_bus_tracker_new/services/route_plan/route_polyline_projection.dart';
import 'package:jordan_bus_tracker_new/services/route_progress_calculator.dart';
import 'package:jordan_bus_tracker_new/services/stop_runtime_snapshot_resolver.dart';

void main() {
  final observedAt = DateTime.utc(2026, 9, 28, 20, 30);
  final evaluatedAt = observedAt.add(const Duration(seconds: 30));
  final freshnessPolicy = EtaFreshnessPolicy(
    maxAge: const Duration(minutes: 1),
  );

  RouteProgressProjection vehicleProjection(double alongMeters) {
    return RouteProgressProjection(
      progress: 0.5,
      alongMeters: alongMeters,
      distanceToRouteMeters: 0,
      segmentIndex: 0,
      segmentT: 0.5,
    );
  }

  RoutePolylineProjection stopProjection(double alongMeters) {
    return RoutePolylineProjection(
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
      acceptedRouteProgress: vehicleProjection(alongMeters),
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
      projection: stopProjection(alongMeters),
    );

    return StopRuntimeSnapshot(
      eligibleProjectedStops: [nextStop],
      nextStop: nextStop,
      statesByStopId: const {},
    );
  }

  test('returns null when observation is absent', () {
    final result = EtaRuntimeInvocation.evaluate(
      observation: null,
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNull);
  });

  test('returns null when stop runtime snapshot is absent', () {
    final result = EtaRuntimeInvocation.evaluate(
      observation: observation(),
      stopRuntimeSnapshot: null,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNull);
  });

  test('returns null when the builder rejects a stale observation', () {
    final staleObservedAt = evaluatedAt.subtract(
      const Duration(seconds: 61),
    );

    final result = EtaRuntimeInvocation.evaluate(
      observation: observation(observedAtOverride: staleObservedAt),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNull);
  });

  test('returns null when the builder rejects a future observation', () {
    final futureObservedAt = evaluatedAt.add(const Duration(seconds: 1));

    final result = EtaRuntimeInvocation.evaluate(
      observation: observation(observedAtOverride: futureObservedAt),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNull);
  });

  test('returns the engine result for a valid EtaInput', () {
    final result = EtaRuntimeInvocation.evaluate(
      observation: observation(),
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(result, isNotNull);
    expect(result!.status, EtaStatus.available);
    expect(result.distanceAheadMeters, closeTo(515, 0.000001));
    expect(result.etaSeconds, closeTo(515 / 8.5, 0.000001));
    expect(result.observedAt, observedAt);
  });

  test(
    'preserves engine unavailable when EtaInput exists but speed is invalid',
    () {
      final result = EtaRuntimeInvocation.evaluate(
        observation: observation(speedMps: 0),
        stopRuntimeSnapshot: snapshotWithNextStop(640),
        freshnessPolicy: freshnessPolicy,
        evaluatedAt: evaluatedAt,
      );

      expect(result, isNotNull);
      expect(result!.status, EtaStatus.unavailable);
      expect(
        result.unavailableReason,
        EtaUnavailableReason.nonPositiveSpeed,
      );
    },
  );

  test(
    'passes targetNotAhead through to the engine instead of filtering it',
    () {
      final result = EtaRuntimeInvocation.evaluate(
        observation: observation(alongMeters: 700),
        stopRuntimeSnapshot: snapshotWithNextStop(640),
        freshnessPolicy: freshnessPolicy,
        evaluatedAt: evaluatedAt,
      );

      expect(result, isNotNull);
      expect(result!.status, EtaStatus.unavailable);
      expect(result.unavailableReason, EtaUnavailableReason.targetNotAhead);
    },
  );

  test('uses the current next stop on each evaluation', () {
    final sourceObservation = observation();
    final first = EtaRuntimeInvocation.evaluate(
      observation: sourceObservation,
      stopRuntimeSnapshot: snapshotWithNextStop(640),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );
    final second = EtaRuntimeInvocation.evaluate(
      observation: sourceObservation,
      stopRuntimeSnapshot: snapshotWithNextStop(800),
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.status, EtaStatus.available);
    expect(second!.status, EtaStatus.available);
    expect(first.distanceAheadMeters, closeTo(515, 0.000001));
    expect(second.distanceAheadMeters, closeTo(675, 0.000001));
    expect(second.etaSeconds, isNot(first.etaSeconds));
  });

  test('produces identical result values for identical inputs', () {
    final sourceObservation = observation();
    final snapshot = snapshotWithNextStop(640);

    final first = EtaRuntimeInvocation.evaluate(
      observation: sourceObservation,
      stopRuntimeSnapshot: snapshot,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );
    final second = EtaRuntimeInvocation.evaluate(
      observation: sourceObservation,
      stopRuntimeSnapshot: snapshot,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.status, first!.status);
    expect(second.etaSeconds, first.etaSeconds);
    expect(second.distanceAheadMeters, first.distanceAheadMeters);
    expect(second.observedAt, first.observedAt);
    expect(second.unavailableReason, first.unavailableReason);
  });
}
