/// Deterministic policy for deciding whether an ETA observation is fresh.
///
/// This policy is integration-layer logic. It does not read the system clock,
/// calculate ETA, or access GPS, Firestore, UI, or runtime state.
enum EtaFreshnessStatus {
  fresh,
  stale,
  future,
}

class EtaFreshnessPolicy {
  final Duration maxAge;

  const EtaFreshnessPolicy({
    required this.maxAge,
  });

  EtaFreshnessStatus evaluate({
    required DateTime observedAt,
    required DateTime evaluatedAt,
  }) {
    final age = evaluatedAt.difference(observedAt);

    if (age.isNegative) {
      return EtaFreshnessStatus.future;
    }

    return age.compareTo(maxAge) <= 0
        ? EtaFreshnessStatus.fresh
        : EtaFreshnessStatus.stale;
  }
}
