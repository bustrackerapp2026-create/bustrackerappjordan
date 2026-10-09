/// Immutable input contract for deterministic ETA calculation.
///
/// The input contains route-axis position, target position, movement speed,
/// and the timestamp of the observation that supplied the data. Freshness is
/// intentionally evaluated outside the ETA engine.
class EtaInput {
  final double vehicleAlongMeters;
  final double targetAlongMeters;
  final double speedMps;
  final DateTime observedAt;

  const EtaInput({
    required this.vehicleAlongMeters,
    required this.targetAlongMeters,
    required this.speedMps,
    required this.observedAt,
  });
}
