import '../models/planned_route.dart';
import 'route_plan/route_polyline_projection.dart';

typedef ApprovedRoutesReader = Future<List<PlannedRoute>> Function();

/// Policy for qualifying a route candidate during JourneyPlanner discovery.
///
/// No default distances are defined here. The caller must provide the policy
/// explicitly so the discovery boundary does not hide planner-specific
/// thresholds.
class RouteCandidateDiscoveryPolicy {
  final double originMaxDistanceMeters;
  final double destinationMaxDistanceMeters;

  RouteCandidateDiscoveryPolicy({
    required this.originMaxDistanceMeters,
    required this.destinationMaxDistanceMeters,
  })  : assert(originMaxDistanceMeters.isFinite),
        assert(destinationMaxDistanceMeters.isFinite),
        assert(originMaxDistanceMeters >= 0),
        assert(destinationMaxDistanceMeters >= 0);

  bool acceptsOriginDistance(double distanceMeters) =>
      distanceMeters <= originMaxDistanceMeters;

  bool acceptsDestinationDistance(double distanceMeters) =>
      distanceMeters <= destinationMaxDistanceMeters;
}

/// Discovers approved PlannedRoutes that can serve an origin/destination pair.
///
/// This boundary is deliberately independent from:
/// - VehicleTrip discovery.
/// - ETA.
/// - Ranking.
/// - UI.
/// - Map rendering.
/// - NearbyRoutesService.
///
/// The service preserves PlannedRoute identity and never deduplicates by
/// lineName.
class RouteCandidateDiscoveryService {
  RouteCandidateDiscoveryService({
    required ApprovedRoutesReader approvedRoutesReader,
    required RouteCandidateDiscoveryPolicy policy,
  })  : _approvedRoutesReader = approvedRoutesReader,
        _policy = policy;

  final ApprovedRoutesReader _approvedRoutesReader;
  final RouteCandidateDiscoveryPolicy _policy;

  Future<List<PlannedRoute>> discover({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    if (!_validCoordinate(originLatitude, originLongitude) ||
        !_validCoordinate(destinationLatitude, destinationLongitude)) {
      return const [];
    }

    final routes = await _approvedRoutesReader();
    final candidates = <PlannedRoute>[];

    for (final route in routes) {
      if (!route.isApproved || route.points.length < 2) {
        continue;
      }

      final originProjection = RoutePolylineProjection.project(
        routePoints: route.points,
        latitude: originLatitude,
        longitude: originLongitude,
      );
      if (originProjection == null ||
          !_policy.acceptsOriginDistance(
            originProjection.distanceToRouteMeters,
          )) {
        continue;
      }

      final destinationProjection = RoutePolylineProjection.project(
        routePoints: route.points,
        latitude: destinationLatitude,
        longitude: destinationLongitude,
      );
      if (destinationProjection == null ||
          !_policy.acceptsDestinationDistance(
            destinationProjection.distanceToRouteMeters,
          )) {
        continue;
      }

      if (destinationProjection.alongMeters <= originProjection.alongMeters) {
        continue;
      }

      candidates.add(route);
    }

    return candidates.toList(growable: false);
  }

  static bool _validCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
