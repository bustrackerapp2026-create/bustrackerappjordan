import '../models/eta_result.dart';
import 'accepted_eta_observation.dart';
import 'eta_engine.dart';
import 'eta_freshness_policy.dart';
import 'eta_input_builder.dart';
import 'stop_runtime_snapshot_resolver.dart';

/// Runtime coordinator for the deterministic ETA path.
///
/// This component coordinates existing integration/domain contracts only. It
/// does not own runtime state, clocks, GPS, Firestore, or Passenger/UI state.
class EtaRuntimeInvocation {
  EtaRuntimeInvocation._();

  static EtaResult? evaluate({
    required AcceptedEtaObservation? observation,
    required StopRuntimeSnapshot? stopRuntimeSnapshot,
    required EtaFreshnessPolicy freshnessPolicy,
    required DateTime evaluatedAt,
  }) {
    final currentObservation = observation;
    final currentSnapshot = stopRuntimeSnapshot;

    if (currentObservation == null || currentSnapshot == null) {
      return null;
    }

    final input = EtaInputBuilder.build(
      observation: currentObservation,
      stopRuntimeSnapshot: currentSnapshot,
      freshnessPolicy: freshnessPolicy,
      evaluatedAt: evaluatedAt,
    );

    if (input == null) {
      return null;
    }

    return EtaEngine.calculate(input);
  }
}
