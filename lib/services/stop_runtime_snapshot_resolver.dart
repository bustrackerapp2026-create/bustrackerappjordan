import '../models/planned_route_stop_model.dart';
import '../models/route_point.dart';
import 'next_stop_resolver.dart';
import 'planned_route_stop_projection.dart';
import 'route_plan/route_plan_geometry.dart';
import 'stop_state_resolver.dart';

/// Runtime-derived view of fixed route stops for one accepted vehicle position.
///
/// This is in-memory only. It is not persisted to Firestore.
class StopRuntimeSnapshot {
  final List<ProjectedPlannedRouteStop> eligibleProjectedStops;
  final ProjectedPlannedRouteStop? nextStop;
  final Map<String, StopState> statesByStopId;

  StopRuntimeSnapshot({
    required List<ProjectedPlannedRouteStop> eligibleProjectedStops,
    required this.nextStop,
    required Map<String, StopState> statesByStopId,
  })  : eligibleProjectedStops =
            List<ProjectedPlannedRouteStop>.unmodifiable(eligibleProjectedStops),
        statesByStopId = Map<String, StopState>.unmodifiable(statesByStopId);
}

/// Builds a deterministic runtime snapshot from already available route data.
///
/// Responsibilities:
/// - project fixed stops onto the route axis;
/// - apply explicit stop eligibility;
/// - resolve NextStop;
/// - classify eligible stops with explicit StopStatePolicy.
///
/// It has no Firestore, GPS, DriverTrackingHub, VehicleTrip, or Mapbox access.
class StopRuntimeSnapshotResolver {
  StopRuntimeSnapshotResolver._();

  static StopRuntimeSnapshot? resolve({
    required List<RoutePoint> routePoints,
    required double vehicleAlongMeters,
    required Iterable<PlannedRouteStopModel> stops,
    required PlannedRouteStopEligibility isEligible,
    required StopStatePolicy statePolicy,
  }) {
    final totalRouteMeters =
        RoutePlanGeometry.totalDistanceMeters(routePoints);

    if (!_validAxisValue(vehicleAlongMeters, totalRouteMeters)) {
      return null;
    }

    final eligibleProjectedStops = <ProjectedPlannedRouteStop>[];
    final statesByStopId = <String, StopState>{};

    for (final stop in stops) {
      final projection = PlannedRouteStopProjection.project(
        stop: stop,
        routePoints: routePoints,
      );
      if (projection == null) {
        continue;
      }

      final candidate = ProjectedPlannedRouteStop(
        stop: stop,
        projection: projection,
      );

      if (!_validProjection(candidate, totalRouteMeters)) {
        continue;
      }

      if (!isEligible(candidate)) {
        continue;
      }

      eligibleProjectedStops.add(candidate);

      final state = StopStateResolver.resolve(
        vehicleAlongMeters: vehicleAlongMeters,
        stopAlongMeters: projection.alongMeters,
        totalRouteMeters: totalRouteMeters,
        policy: statePolicy,
      );
      if (state != null) {
        statesByStopId[stop.id] = state;
      }
    }

    final nextStop = NextStopResolver.resolve(
      vehicleAlongMeters: vehicleAlongMeters,
      projectedStops: eligibleProjectedStops,
      isEligible: (_) => true,
    );

    return StopRuntimeSnapshot(
      eligibleProjectedStops: eligibleProjectedStops,
      nextStop: nextStop,
      statesByStopId: statesByStopId,
    );
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

  static bool _validProjection(
    ProjectedPlannedRouteStop candidate,
    double totalRouteMeters,
  ) {
    final alongMeters = candidate.projection.alongMeters;
    final distanceToRouteMeters =
        candidate.projection.distanceToRouteMeters;

    return alongMeters.isFinite &&
        distanceToRouteMeters.isFinite &&
        alongMeters >= 0 &&
        alongMeters <= totalRouteMeters &&
        distanceToRouteMeters >= 0;
  }
}
