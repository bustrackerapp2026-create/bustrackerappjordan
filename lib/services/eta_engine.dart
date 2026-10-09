import '../models/eta_input.dart';
import '../models/eta_result.dart';
import '../models/eta_status.dart';
import '../models/eta_unavailable_reason.dart';

/// Pure deterministic domain calculation for ETA to a target on a route axis.
///
/// This engine does not access GPS, Firestore, Flutter UI, Mapbox, runtime
/// tracking state, stop runtime data, or the system clock. Freshness checks
/// belong to the integration layer.
class EtaEngine {
  EtaEngine._();

  static EtaResult calculate(EtaInput input) {
    if (!_validNonNegativeFinite(input.vehicleAlongMeters)) {
      return _unavailable(
        input,
        EtaUnavailableReason.invalidVehicleProgress,
      );
    }

    if (!_validNonNegativeFinite(input.targetAlongMeters)) {
      return _unavailable(
        input,
        EtaUnavailableReason.invalidTarget,
      );
    }

    if (input.targetAlongMeters <= input.vehicleAlongMeters) {
      return _unavailable(
        input,
        EtaUnavailableReason.targetNotAhead,
      );
    }

    if (!input.speedMps.isFinite) {
      return _unavailable(
        input,
        EtaUnavailableReason.invalidSpeed,
      );
    }

    if (input.speedMps <= 0) {
      return _unavailable(
        input,
        EtaUnavailableReason.nonPositiveSpeed,
      );
    }

    final distanceAheadMeters =
        input.targetAlongMeters - input.vehicleAlongMeters;
    final etaSeconds = distanceAheadMeters / input.speedMps;

    return EtaResult(
      status: EtaStatus.available,
      etaSeconds: etaSeconds,
      distanceAheadMeters: distanceAheadMeters,
      observedAt: input.observedAt,
      unavailableReason: null,
    );
  }

  static bool _validNonNegativeFinite(double value) {
    return value.isFinite && value >= 0;
  }

  static EtaResult _unavailable(
    EtaInput input,
    EtaUnavailableReason reason,
  ) {
    return EtaResult(
      status: EtaStatus.unavailable,
      etaSeconds: null,
      distanceAheadMeters: null,
      observedAt: input.observedAt,
      unavailableReason: reason,
    );
  }
}
