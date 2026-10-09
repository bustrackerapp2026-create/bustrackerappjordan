/// Explicit reasons why the deterministic ETA cannot be produced.
enum EtaUnavailableReason {
  invalidVehicleProgress,
  invalidTarget,
  targetNotAhead,
  invalidSpeed,
  nonPositiveSpeed,
}
