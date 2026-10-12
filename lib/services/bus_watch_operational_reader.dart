import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_driver_location.dart';
import '../models/planned_route.dart';
import '../models/trip_model.dart';
import '../models/vehicle_trip.dart';
import 'bus_watch_operational_read_result.dart';
import 'vehicle_trip_service.dart';

typedef BusWatchPassengerTripReader = Future<TripModel?> Function(
  String passengerTripId,
);

typedef BusWatchActiveVehicleTripReader = Future<VehicleTrip?> Function(
  String driverId,
);

typedef BusWatchLiveLocationReader = Future<LiveDriverLocation?> Function(
  String driverId,
);

typedef BusWatchPlannedRouteReader = Future<PlannedRoute?> Function(
  String routeId,
);

/// One-shot read model for a specific Passenger Trip.
///
/// The reader has no retained runtime state, cache, scheduler, or long-lived
/// stream. Firestore/infrastructure errors are allowed to propagate instead
/// of being collapsed into a domain absence status.
class BusWatchOperationalReader {
  final BusWatchPassengerTripReader _readPassengerTrip;
  final BusWatchActiveVehicleTripReader _readActiveVehicleTrip;
  final BusWatchLiveLocationReader _readLiveLocation;
  final BusWatchPlannedRouteReader _readPlannedRoute;

  BusWatchOperationalReader({
    FirebaseFirestore? firestore,
    BusWatchPassengerTripReader? readPassengerTrip,
    BusWatchActiveVehicleTripReader? readActiveVehicleTrip,
    BusWatchLiveLocationReader? readLiveLocation,
    BusWatchPlannedRouteReader? readPlannedRoute,
  })  : _readPassengerTrip = readPassengerTrip ??
            _firestorePassengerTripReader(
              firestore ?? FirebaseFirestore.instance,
            ),
        _readActiveVehicleTrip =
            readActiveVehicleTrip ?? VehicleTripService().findActiveTripForDriver,
        _readLiveLocation = readLiveLocation ??
            _firestoreLiveLocationReader(
              firestore ?? FirebaseFirestore.instance,
            ),
        _readPlannedRoute = readPlannedRoute ??
            _firestorePlannedRouteReader(
              firestore ?? FirebaseFirestore.instance,
            );

  Future<BusWatchOperationalReadResult> read({
    String? passengerTripId,
  }) async {
    final tripId = passengerTripId?.trim() ?? '';
    if (tripId.isEmpty) {
      return BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noPassengerContext,
      );
    }

    final passengerTrip = await _readPassengerTrip(tripId);
    if (passengerTrip == null) {
      return BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noPassengerContext,
      );
    }

    final driverId = passengerTrip.driverId.trim();
    if (driverId.isEmpty) {
      return BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noActiveVehicleTrip,
      );
    }

    final vehicleTrip = await _readActiveVehicleTrip(driverId);
    if (vehicleTrip == null ||
        !vehicleTrip.isActive ||
        vehicleTrip.driverId != driverId) {
      return BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noActiveVehicleTrip,
      );
    }

    final liveLocation = await _readLiveLocation(driverId);
    if (liveLocation == null ||
        liveLocation.driverId != driverId ||
        !liveLocation.hasValidCoords) {
      return BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noLiveLocation,
      );
    }

    final routeId = vehicleTrip.routeId.trim();
    if (routeId.isEmpty) {
      return BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noApprovedRoute,
      );
    }

    final plannedRoute = await _readPlannedRoute(routeId);
    if (plannedRoute == null ||
        plannedRoute.id != routeId ||
        !plannedRoute.isApproved ||
        plannedRoute.points.length < 2) {
      return BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noApprovedRoute,
      );
    }

    return BusWatchOperationalReadResult.available(
      BusWatchOperationalSnapshot(
        passengerTripId: passengerTrip.id,
        vehicleTripId: vehicleTrip.id,
        driverId: driverId,
        busNumber: vehicleTrip.busNumber,
        routeId: vehicleTrip.routeId,
        direction: vehicleTrip.direction,
        status: vehicleTrip.status,
        liveLocation: liveLocation,
        speed: liveLocation.speed,
        heading: liveLocation.heading,
        routeProgress: vehicleTrip.routeProgress,
        lastLocationAt: liveLocation.updatedAt,
        approvedRoute: plannedRoute,
      ),
    );
  }

  static BusWatchPassengerTripReader _firestorePassengerTripReader(
    FirebaseFirestore firestore,
  ) {
    return (tripId) async {
      final doc = await firestore.collection('trips').doc(tripId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TripModel.fromMap(doc.data()!, doc.id);
    };
  }

  static BusWatchLiveLocationReader _firestoreLiveLocationReader(
    FirebaseFirestore firestore,
  ) {
    return (driverId) async {
      final doc =
          await firestore.collection('driverPublic').doc(driverId).get();
      if (!doc.exists || doc.data() == null) return null;
      return LiveDriverLocation.fromPublicDoc(driverId, doc.data()!);
    };
  }

  static BusWatchPlannedRouteReader _firestorePlannedRouteReader(
    FirebaseFirestore firestore,
  ) {
    return (routeId) async {
      final doc =
          await firestore.collection('plannedRoutes').doc(routeId).get();
      if (!doc.exists || doc.data() == null) return null;
      return PlannedRoute.fromDoc(routeId, doc.data()!);
    };
  }
}
