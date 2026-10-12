import '../models/eta_input.dart';
import 'accepted_eta_observation.dart';
import 'eta_freshness_policy.dart';
import 'stop_runtime_snapshot_resolver.dart';

/// Composes a deterministic EtaInput from accepted runtime data.
///
/// Freshness is evaluated before composition. This builder does not calculate
/// ETA, access the system clock, resolve stops, access GPS, or read Firestore.
class EtaInputBuilder {
  EtaInputBuilder._();

  static EtaInput? build({
    required AcceptedEtaObservation observation,
    required StopRuntimeSnapshot stopRuntimeSnapshot,
    required EtaFreshnessPolicy freshnessPolicy,
    required DateTime evaluatedAt,
  }) {
    final freshness = freshnessPolicy.evaluate(
      observedAt: observation.observedAt,
      evaluatedAt: evaluatedAt,
    );

    if (freshness != EtaFreshnessStatus.fresh) {
      return null;
    }

    final nextStop = stopRuntimeSnapshot.nextStop;
    if (nextStop == null) {
      return null;
    }

    return EtaInput(
      vehicleAlongMeters: observation.acceptedRouteProgress.alongMeters,
      targetAlongMeters: nextStop.projection.alongMeters,
      speedMps: observation.speedMps,
      observedAt: observation.observedAt,
    );
  }
}
