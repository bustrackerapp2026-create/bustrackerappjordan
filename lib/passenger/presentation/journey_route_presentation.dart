import '../../models/planned_route.dart';
import '../../models/vehicle_trip.dart';

/// Extracts each distinct route once for exact presentation.
List<PlannedRoute> journeyOptionRoutesForPresentation(
  List<({
    PlannedRoute route,
    VehicleTrip vehicleTrip,
  })> options,
) {
  final seen = <String>{};
  final routes = <PlannedRoute>[];

  for (final option in options) {
    final key = '${option.route.id}\u0000'
        '${option.route.direction.firestoreValue}';
    if (seen.add(key)) {
      routes.add(option.route);
    }
  }

  return List<PlannedRoute>.unmodifiable(routes);
}