import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_progress_calculator.dart';

/// Stateful guard for RouteProgress continuity and monotonic progression.
///
/// This layer keeps RouteProgress independent from Firestore, DriverTrackingHub,
/// and the map UI. It accepts normal forward movement, clamps small backward
/// GPS jitter to the last accepted position, and rejects implausibly large
/// forward projection jumps.
class RouteProgressTracker {
  static const double maxForwardJumpMeters = 300.0;

  RouteProgressProjection? _lastAccepted;

  RouteProgressProjection? get lastAccepted => _lastAccepted;

  void reset() {
    _lastAccepted = null;
  }

  /// Accepts a new GPS projection when it is consistent with the current
  /// state. A backward projection is clamped to the last accepted progress;
  /// an excessively large forward jump is rejected.
  RouteProgressProjection? update({
    required List<RoutePoint> routePoints,
    required double latitude,
    required double longitude,
    double? accuracy,
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
      return monotonic;
    }

    _lastAccepted = candidate;
    return candidate;
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
    return true;
  }
}
