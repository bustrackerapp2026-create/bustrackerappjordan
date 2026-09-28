import '../models/planned_route_stop_model.dart';
import 'route_plan/route_polyline_projection.dart';

/// Stop projected onto a PlannedRoute, ready for domain resolution.
///
/// The projection is computed upstream by [PlannedRouteStopProjection];
/// this value carries the stop and its existing geometry result together.
class ProjectedPlannedRouteStop {
  final PlannedRouteStopModel stop;
  final RoutePolylineProjection projection;

  const ProjectedPlannedRouteStop({
    required this.stop,
    required this.projection,
  });
}

/// Domain policy supplied by the caller to decide whether a projected stop
/// is operationally eligible to enter NextStop candidates.
typedef PlannedRouteStopEligibility = bool Function(
  ProjectedPlannedRouteStop candidate,
);

/// Resolves the nearest eligible fixed stop strictly ahead of the vehicle.
///
/// This resolver does not perform GPS projection, Firestore access, or any
/// distance-threshold policy. It consumes ready projections and an explicit
/// eligibility policy.
class NextStopResolver {
  NextStopResolver._();

  static ProjectedPlannedRouteStop? resolve({
    required double vehicleAlongMeters,
    required Iterable<ProjectedPlannedRouteStop> projectedStops,
    required PlannedRouteStopEligibility isEligible,
  }) {
    if (!vehicleAlongMeters.isFinite || vehicleAlongMeters < 0) {
      return null;
    }

    ProjectedPlannedRouteStop? best;
    var bestDelta = double.infinity;

    for (final candidate in projectedStops) {
      final alongMeters = candidate.projection.alongMeters;
      final distanceToRouteMeters =
          candidate.projection.distanceToRouteMeters;

      if (!alongMeters.isFinite ||
          !distanceToRouteMeters.isFinite ||
          alongMeters < 0 ||
          distanceToRouteMeters < 0) {
        continue;
      }

      if (!isEligible(candidate)) {
        continue;
      }

      if (vehicleAlongMeters >= alongMeters) {
        continue;
      }

      final delta = alongMeters - vehicleAlongMeters;

      if (delta < bestDelta ||
          (delta == bestDelta &&
              (best == null || candidate.stop.order < best.stop.order))) {
        best = candidate;
        bestDelta = delta;
      }
    }

    return best;
  }
}
