import '../models/live_driver_location.dart';
import '../models/planned_route.dart';
import '../models/vehicle_trip.dart';

enum BusWatchOperationalReadStatus {
  available,
  noPassengerContext,
  noActiveVehicleTrip,
  noLiveLocation,
  noApprovedRoute,
}

/// لقطة تشغيلية immutable لرحلة Passenger محددة.
/// لا تحمل ETA أو Stop Runtime أو AcceptedEtaObservation.
class BusWatchOperationalSnapshot {
  final String passengerTripId;
  final String vehicleTripId;
  final String driverId;
  final String busNumber;
  final String routeId;
  final String direction;
  final VehicleTripStatus status;
  final LiveDriverLocation liveLocation;
  final double? speed;
  final double? heading;
  final double? routeProgress;
  final DateTime? lastLocationAt;
  final PlannedRoute approvedRoute;

  const BusWatchOperationalSnapshot({
    required this.passengerTripId,
    required this.vehicleTripId,
    required this.driverId,
    required this.busNumber,
    required this.routeId,
    required this.direction,
    required this.status,
    required this.liveLocation,
    required this.speed,
    required this.heading,
    required this.routeProgress,
    required this.lastLocationAt,
    required this.approvedRoute,
  });
}

/// نتيجة قراءة typed بحالة واحدة حاسمة.
///
/// invariant:
/// - available => snapshot != null
/// - any non-available status => snapshot == null
class BusWatchOperationalReadResult {
  final BusWatchOperationalReadStatus status;
  final BusWatchOperationalSnapshot? snapshot;

  const BusWatchOperationalReadResult._({
    required this.status,
    required this.snapshot,
  });

  const BusWatchOperationalReadResult.available(
    BusWatchOperationalSnapshot snapshot,
  ) : this._(
          status: BusWatchOperationalReadStatus.available,
          snapshot: snapshot,
        );

  factory BusWatchOperationalReadResult.unavailable(
    BusWatchOperationalReadStatus status,
  ) {
    if (status == BusWatchOperationalReadStatus.available) {
      throw ArgumentError(
        'Use BusWatchOperationalReadResult.available for available results.',
      );
    }
    return BusWatchOperationalReadResult._(
      status: status,
      snapshot: null,
    );
  }

  bool get isAvailable =>
      status == BusWatchOperationalReadStatus.available;
}
