import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_progress_calculator.dart';
import 'route_progress_physical_plausibility_policy.dart';

/// Stateful guard for RouteProgress continuity and monotonic progression.
///
/// This layer keeps RouteProgress independent from Firestore, DriverTrackingHub,
/// and the map UI. It accepts normal forward movement, clamps small backward
/// GPS jitter to the last accepted position, and rejects implausibly large
/// forward projection jumps.
///
/// Physical plausibility only constrains positive forward movement. When the
/// physical gate is unavailable, the existing 300 m continuity guard remains
/// the only forward-jump limit.
class RouteProgressTracker {
  static const double maxForwardJumpMeters = 300.0;

  RouteProgressProjection? _lastAccepted;
  DateTime? _lastAcceptedTimestamp;
  double? _lastAcceptedValidSpeedMetersPerSecond;

  RouteProgressProjection? get lastAccepted => _lastAccepted;

  void reset() {
    _lastAccepted = null;
    _lastAcceptedTimestamp = null;
    _lastAcceptedValidSpeedMetersPerSecond = null;
  }

  /// Accepts a new GPS projection when it is consistent with the current
  /// state. A backward projection is clamped to the last accepted progress;
  /// an excessively large forward jump is rejected.
  ///
  /// [timestamp] and [speedMetersPerSecond] are used only to constrain
  /// positive forward movement through the physical plausibility policy.
  RouteProgressProjection? update({
    required List<RoutePoint> routePoints,
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? timestamp,
    double? speedMetersPerSecond,
  }) {
    final candidate = RouteProgressCalculator.project(
      routePoints: routePoints,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
    if (candidate == null) {
      return null;
    }

    final previous = _lastAccepted;
    if (previous == null) {
      _lastAccepted = candidate;
      _recordAcceptedPhysicalState(
        timestamp: timestamp,
        speedMetersPerSecond: speedMetersPerSecond,
      );
      return candidate;
    }

    final forwardDelta = candidate.alongMeters - previous.alongMeters;

    if (forwardDelta > maxForwardJumpMeters) {
      return previous;
    }

    if (candidate.alongMeters < previous.alongMeters) {
      final monotonic = RouteProgressProjection(
        progress: previous.progress,
        alongMeters: previous.alongMeters,
        distanceToRouteMeters: candidate.distanceToRouteMeters,
        segmentIndex: candidate.segmentIndex,
        segmentT: candidate.segmentT,
      );
      _lastAccepted = monotonic;
      _recordAcceptedPhysicalState(
        timestamp: timestamp,
        speedMetersPerSecond: speedMetersPerSecond,
      );
      return monotonic;
    }

    if (forwardDelta > 0) {
      final physicalResult =
          RouteProgressPhysicalPlausibilityPolicy.evaluate(
        previousTimestamp: _lastAcceptedTimestamp,
        currentTimestamp: timestamp,
        previousValidSpeedMetersPerSecond:
            _lastAcceptedValidSpeedMetersPerSecond,
        currentValidSpeedMetersPerSecond: speedMetersPerSecond,
      );

      if (physicalResult
          case RouteProgressPhysicalPlausibilityConstrained(
            maxAllowedForwardDistanceMeters: final maxAllowed,
          )) {
        if (forwardDelta > maxAllowed) {
          return previous;
        }
      }
    }

    _lastAccepted = candidate;
    _recordAcceptedPhysicalState(
      timestamp: timestamp,
      speedMetersPerSecond: speedMetersPerSecond,
    );
    return candidate;
  }

  void _recordAcceptedPhysicalState({
    required DateTime? timestamp,
    required double? speedMetersPerSecond,
  }) {
    _lastAcceptedTimestamp = timestamp;
    _lastAcceptedValidSpeedMetersPerSecond =
        _validSpeedOrNull(speedMetersPerSecond);
  }

  double? _validSpeedOrNull(double? speedMetersPerSecond) {
    if (speedMetersPerSecond == null ||
        !speedMetersPerSecond.isFinite ||
        speedMetersPerSecond < 0) {
      return null;
    }
    return speedMetersPerSecond;
  }

  /// Seeds continuity from a persisted RouteProgress value.
  ///
  /// The persisted progress is converted to along-route meters using the
  /// current route geometry so the next GPS sample cannot move backwards.
  bool seedFromProgress({
    required List<RoutePoint> routePoints,
    required double progress,
  }) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      return false;
    }

    final totalRouteMeters = RoutePlanGeometry.totalDistanceMeters(routePoints);
    if (!totalRouteMeters.isFinite || totalRouteMeters <= 0) {
      return false;
    }

    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    _lastAccepted = RouteProgressProjection(
      progress: normalizedProgress,
      alongMeters: normalizedProgress * totalRouteMeters,
      distanceToRouteMeters: 0.0,
      segmentIndex: 0,
      segmentT: 0.0,
    );
    _lastAcceptedTimestamp = null;
    _lastAcceptedValidSpeedMetersPerSecond = null;
    return true;
  }
}
