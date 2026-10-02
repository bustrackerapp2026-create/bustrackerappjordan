import 'dart:math' as math;

import '../models/planned_route.dart';
import '../models/vehicle_trip.dart';
import 'vehicle_location_freshness_policy.dart';

enum ClosestCriterionStatus {
  available,
  unavailable,
}

class ClosestCriterionResult {
  final ClosestCriterionStatus status;
  final double? distanceMeters;

  const ClosestCriterionResult.available(
    double distanceMeters,
  ) : this._(
          status: ClosestCriterionStatus.available,
          distanceMeters: distanceMeters,
        );

  const ClosestCriterionResult.unavailable()
      : this._(
          status: ClosestCriterionStatus.unavailable,
          distanceMeters: null,
        );

  const ClosestCriterionResult._({
    required this.status,
    required this.distanceMeters,
  });

  bool get isAvailable => status == ClosestCriterionStatus.available;
}

/// Deterministic Closest criterion for a JourneyPlanner association.
///
/// The measured distance is straight-line distance in meters from the current
/// VehicleTrip location to the passenger Origin. Location eligibility is
/// decided only by the injected freshness policy and explicit coordinate
/// validation. This criterion does not read clocks, infer locations, call
/// ETA, access Firestore, or mutate the JourneyPlanner association.
class ClosestCriterion {
  ClosestCriterion._();

  static ClosestCriterionResult evaluate({
    required VehicleTrip vehicleTrip,
    required double originLatitude,
    required double originLongitude,
    required VehicleLocationFreshnessPolicy freshnessPolicy,
    required DateTime evaluatedAt,
  }) {
    if (!_validCoordinate(originLatitude, originLongitude)) {
      return const ClosestCriterionResult.unavailable();
    }

    final location = vehicleTrip.currentLocation;
    if (location == null) {
      return const ClosestCriterionResult.unavailable();
    }

    final freshness = freshnessPolicy.evaluate(
      lastLocationAt: vehicleTrip.lastLocationAt,
      evaluatedAt: evaluatedAt,
    );
    if (freshness != VehicleLocationFreshnessStatus.fresh) {
      return const ClosestCriterionResult.unavailable();
    }

    if (!_validCoordinate(location.latitude, location.longitude)) {
      return const ClosestCriterionResult.unavailable();
    }

    final distanceMeters = _distanceMeters(
      originLatitude,
      originLongitude,
      location.latitude,
      location.longitude,
    );

    if (!distanceMeters.isFinite) {
      return const ClosestCriterionResult.unavailable();
    }

    return ClosestCriterionResult.available(distanceMeters);
  }

  /// Deterministic association tie-break used after equal Closest distances.
  ///
  /// Ordering is lexicographic by route.id, route direction, then
  /// vehicleTrip.id. This method never decides whether an option is valid.
  static int compareTieBreak({
    required PlannedRoute firstRoute,
    required VehicleTrip firstVehicleTrip,
    required PlannedRoute secondRoute,
    required VehicleTrip secondVehicleTrip,
  }) {
    final firstKey = (
      firstRoute.id.trim(),
      firstRoute.direction.firestoreValue.trim(),
      firstVehicleTrip.id.trim(),
    );
    final secondKey = (
      secondRoute.id.trim(),
      secondRoute.direction.firestoreValue.trim(),
      secondVehicleTrip.id.trim(),
    );

    final routeCompare = firstKey.$1.compareTo(secondKey.$1);
    if (routeCompare != 0) return routeCompare;

    final directionCompare = firstKey.$2.compareTo(secondKey.$2);
    if (directionCompare != 0) return directionCompare;

    return firstKey.$3.compareTo(secondKey.$3);
  }

  static bool _validCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final clampedA = a.clamp(0.0, 1.0);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(clampedA), math.sqrt(1 - clampedA));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
