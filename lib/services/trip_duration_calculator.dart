import '../models/vehicle_trip.dart';

/// Pure deterministic calculation of elapsed duration for a completed
/// operational VehicleTrip.
///
/// This calculator does not access Firestore, GPS, TripPing, ETA, UI,
/// or the system clock.
class TripDurationCalculator {
  TripDurationCalculator._();

  static Duration? calculate(VehicleTrip vehicleTrip) {
    if (vehicleTrip.status != VehicleTripStatus.completed) {
      return null;
    }

    final startedAt = vehicleTrip.startedAt;
    final endedAt = vehicleTrip.endedAt;

    if (startedAt == null || endedAt == null) {
      return null;
    }

    if (endedAt.isBefore(startedAt)) {
      return null;
    }

    return endedAt.difference(startedAt);
  }
}
