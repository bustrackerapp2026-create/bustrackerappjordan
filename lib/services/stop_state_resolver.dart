/// Deterministic domain states for a fixed route stop.
enum StopState {
  upcoming,
  approaching,
  atStop,
  passed,
}

/// Numeric policy used to classify a stop on the route axis.
///
/// The policy deliberately contains no default distance values.
class StopStatePolicy {
  final double atStopRadius;
  final double approachingDistance;

  const StopStatePolicy({
    required this.atStopRadius,
    required this.approachingDistance,
  }) {
    if (!atStopRadius.isFinite || atStopRadius <= 0) {
      throw ArgumentError('atStopRadius يجب أن يكون finite و > 0.');
    }
    if (!approachingDistance.isFinite ||
        approachingDistance <= atStopRadius) {
      throw ArgumentError(
        'approachingDistance يجب أن يكون finite و > atStopRadius.',
      );
    }
  }
}

/// Pure domain resolver for fixed-stop state.
///
/// It consumes along-route values only. It does not know GPS, projection,
/// NextStop, Firestore, or runtime tracking.
class StopStateResolver {
  StopStateResolver._();

  static StopState? resolve({
    required double vehicleAlongMeters,
    required double stopAlongMeters,
    required double totalRouteMeters,
    required StopStatePolicy policy,
  }) {
    if (!_validAxisValue(vehicleAlongMeters, totalRouteMeters) ||
        !_validAxisValue(stopAlongMeters, totalRouteMeters)) {
      return null;
    }

    final delta = stopAlongMeters - vehicleAlongMeters;

    if (delta < -policy.atStopRadius) {
      return StopState.passed;
    }

    if (delta <= policy.atStopRadius) {
      return StopState.atStop;
    }

    if (delta <= policy.approachingDistance) {
      return StopState.approaching;
    }

    return StopState.upcoming;
  }

  static bool _validAxisValue(
    double value,
    double totalRouteMeters,
  ) {
    return value.isFinite &&
        totalRouteMeters.isFinite &&
        totalRouteMeters > 0 &&
        value >= 0 &&
        value <= totalRouteMeters;
  }
}
