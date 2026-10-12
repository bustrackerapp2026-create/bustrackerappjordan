/// Result of the RouteProgress physical plausibility policy.
sealed class RouteProgressPhysicalPlausibilityResult {
  const RouteProgressPhysicalPlausibilityResult();

  const factory RouteProgressPhysicalPlausibilityResult.constrained(
    double maxAllowedForwardDistanceMeters,
  ) = RouteProgressPhysicalPlausibilityConstrained;

  const factory RouteProgressPhysicalPlausibilityResult.unavailable() =
      RouteProgressPhysicalPlausibilityUnavailable;
}

/// Physical plausibility is available and constrains forward movement.
final class RouteProgressPhysicalPlausibilityConstrained
    extends RouteProgressPhysicalPlausibilityResult {
  final double maxAllowedForwardDistanceMeters;

  const RouteProgressPhysicalPlausibilityConstrained(
    this.maxAllowedForwardDistanceMeters,
  );
}

/// Physical plausibility cannot be established for this sample.
final class RouteProgressPhysicalPlausibilityUnavailable
    extends RouteProgressPhysicalPlausibilityResult {
  const RouteProgressPhysicalPlausibilityUnavailable();
}

/// Policy for bounding forward RouteProgress movement using GPS timestamps
/// and the speed of the last accepted/current sample.
///
/// This policy is intentionally independent from RouteProgressTracker,
/// DriverTrackingHub, Firestore, GPS APIs, and UI.
class RouteProgressPhysicalPlausibilityPolicy {
  RouteProgressPhysicalPlausibilityPolicy._();

  static const double safetyFactor = 1.5;
  static const double safetyMarginMeters = 20.0;
  static const double hardCapMeters = 300.0;
  static const Duration maxConstrainedElapsed = Duration(seconds: 30);

  static RouteProgressPhysicalPlausibilityResult evaluate({
    required DateTime? previousTimestamp,
    required DateTime? currentTimestamp,
    required double? previousValidSpeedMetersPerSecond,
    required double? currentValidSpeedMetersPerSecond,
  }) {
    if (previousTimestamp == null || currentTimestamp == null) {
      return const RouteProgressPhysicalPlausibilityResult.unavailable();
    }

    final elapsed = currentTimestamp.difference(previousTimestamp);

    if (elapsed.isNegative) {
      return const RouteProgressPhysicalPlausibilityResult.unavailable();
    }

    if (elapsed == Duration.zero) {
      return const RouteProgressPhysicalPlausibilityResult.constrained(0.0);
    }

    if (elapsed > maxConstrainedElapsed) {
      return const RouteProgressPhysicalPlausibilityResult.unavailable();
    }

    final effectiveSpeed = _effectiveSpeed(
      currentValidSpeedMetersPerSecond,
      previousValidSpeedMetersPerSecond,
    );
    if (effectiveSpeed == null) {
      return const RouteProgressPhysicalPlausibilityResult.unavailable();
    }

    final elapsedSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final allowed = (effectiveSpeed * elapsedSeconds * safetyFactor) +
        safetyMarginMeters;

    return RouteProgressPhysicalPlausibilityResult.constrained(
      allowed > hardCapMeters ? hardCapMeters : allowed,
    );
  }

  static double? _effectiveSpeed(
    double? currentSpeed,
    double? previousSpeed,
  ) {
    if (_isValidSpeed(currentSpeed)) return currentSpeed;
    if (_isValidSpeed(previousSpeed)) return previousSpeed;
    return null;
  }

  static bool _isValidSpeed(double? speed) {
    return speed != null && speed.isFinite && speed >= 0;
  }
}
