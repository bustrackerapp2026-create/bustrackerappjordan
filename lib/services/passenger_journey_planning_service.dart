import '../models/planned_route.dart';
import '../models/vehicle_trip.dart';
import 'journey_route_vehicle_association_service.dart';
import 'route_candidate_discovery_service.dart';

/// Orchestrates passenger route discovery and route/vehicle association.
///
/// This service deliberately owns no discovery, matching, ETA, ranking,
/// freshness, UI, Mapbox, or Firestore rules. It only runs the two existing
/// JourneyPlanner steps in order and returns their unchanged associations.
class PassengerJourneyPlanningService {
  PassengerJourneyPlanningService({
    required RouteCandidateDiscoveryService routeCandidateDiscoveryService,
    required JourneyRouteVehicleAssociationService associationService,
  })  : _routeCandidateDiscoveryService = routeCandidateDiscoveryService,
        _associationService = associationService;

  final RouteCandidateDiscoveryService _routeCandidateDiscoveryService;
  final JourneyRouteVehicleAssociationService _associationService;

  Future<List<({
    PlannedRoute route,
    VehicleTrip vehicleTrip,
  })>> plan({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final routeCandidates = await _routeCandidateDiscoveryService.discover(
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );

    if (routeCandidates.isEmpty) {
      return const [];
    }

    return _associationService.associate(
      routeCandidates: routeCandidates,
    );
  }
}
