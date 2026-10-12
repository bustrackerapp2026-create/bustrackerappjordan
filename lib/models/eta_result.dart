import 'eta_status.dart';
import 'eta_unavailable_reason.dart';

/// Structured result returned by the deterministic ETA engine.
class EtaResult {
  final EtaStatus status;
  final double? etaSeconds;
  final double? distanceAheadMeters;
  final DateTime observedAt;
  final EtaUnavailableReason? unavailableReason;

  const EtaResult({
    required this.status,
    required this.etaSeconds,
    required this.distanceAheadMeters,
    required this.observedAt,
    required this.unavailableReason,
  });
}
