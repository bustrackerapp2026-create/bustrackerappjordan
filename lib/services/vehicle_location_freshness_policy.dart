/// Deterministic freshness policy for a VehicleTrip live location.
///
/// The policy evaluates an externally supplied evaluation time. It never
/// reads the system clock and is intentionally scoped to Ranking use.
enum VehicleLocationFreshnessStatus {
  fresh,
  stale,
  future,
  missing,
}

class VehicleLocationFreshnessPolicy {
  final Duration maxAge;

  const VehicleLocationFreshnessPolicy({
    required this.maxAge,
  }) : assert(!maxAge.isNegative);

  VehicleLocationFreshnessStatus evaluate({
    required DateTime? lastLocationAt,
    required DateTime evaluatedAt,
  }) {
    if (lastLocationAt == null) {
      return VehicleLocationFreshnessStatus.missing;
    }

    final age = evaluatedAt.difference(lastLocationAt);
    if (age.isNegative) {
      return VehicleLocationFreshnessStatus.future;
    }

    return age.compareTo(maxAge) <= 0
        ? VehicleLocationFreshnessStatus.fresh
        : VehicleLocationFreshnessStatus.stale;
  }
}
