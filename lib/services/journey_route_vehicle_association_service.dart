import '../models/planned_route.dart';
import '../models/vehicle_trip.dart';
import 'vehicle_trip_service.dart';

/// Builds the first JourneyPlanner association set from route candidates
/// and their matching active vehicle trips.
///
/// This service does not rank, score, or evaluate ETA/location readiness.
/// It only applies the already-frozen route/vehicle identity relationship.
class JourneyRouteVehicleAssociationService {
  JourneyRouteVehicleAssociationService({
    required VehicleTripService vehicleTripService,
  }) : _vehicleTripService = vehicleTripService;

  final VehicleTripService _vehicleTripService;

  Future<List<({
    PlannedRoute route,
    VehicleTrip vehicleTrip,
  })>> associate({
    required List<PlannedRoute> routeCandidates,
  }) async {
    final associations = <({
      PlannedRoute route,
      VehicleTrip vehicleTrip,
    })>[];

    for (final route in routeCandidates) {
      final activeTrips =
          await _vehicleTripService.findActiveTripsForRoute(
        routeId: route.id,
        direction: route.direction.firestoreValue,
      );

      for (final vehicleTrip in activeTrips) {
        associations.add((
          route: route,
          vehicleTrip: vehicleTrip,
        ));
      }
    }

    return associations.toList(growable: false);
  }
}
