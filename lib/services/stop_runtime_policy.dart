import 'package:jordan_bus_tracker_new/services/next_stop_resolver.dart';
import 'package:jordan_bus_tracker_new/services/stop_state_resolver.dart';

/// Production policy for deriving runtime information for fixed route stops.
///
/// The numeric values are centralized here so runtime consumers do not invent
/// thresholds and domain resolvers remain policy-agnostic.
class StopRuntimePolicy {
  static const double productionStopEligibilityDistanceMeters = 75.0;
  static const double productionAtStopRadiusMeters = 30.0;
  static const double productionApproachingDistanceMeters = 200.0;

  final double stopEligibilityDistanceMeters;
  final StopStatePolicy statePolicy;

  StopRuntimePolicy({
    required this.stopEligibilityDistanceMeters,
    required this.statePolicy,
  }) {
    if (!stopEligibilityDistanceMeters.isFinite ||
        stopEligibilityDistanceMeters <= 0) {
      throw ArgumentError(
        'stopEligibilityDistanceMeters يجب أن يكون finite و > 0.',
      );
    }
  }

  /// The currently approved production baseline for the first runtime
  /// integration.
  factory StopRuntimePolicy.production() {
    return StopRuntimePolicy(
      stopEligibilityDistanceMeters:
          productionStopEligibilityDistanceMeters,
      statePolicy: StopStatePolicy(
        atStopRadius: productionAtStopRadiusMeters,
        approachingDistance: productionApproachingDistanceMeters,
      ),
    );
  }

  /// Stop eligibility policy based only on the projected distance from the
  /// stop to the approved route polyline.
  bool isEligible(ProjectedPlannedRouteStop candidate) {
    final distanceToRouteMeters =
        candidate.projection.distanceToRouteMeters;

    return distanceToRouteMeters.isFinite &&
        distanceToRouteMeters >= 0 &&
        distanceToRouteMeters <= stopEligibilityDistanceMeters;
  }

  PlannedRouteStopEligibility get eligibility => isEligible;
}
