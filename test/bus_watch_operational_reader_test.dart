import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/live_driver_location.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/models/trip_model.dart';
import 'package:jordan_bus_tracker_new/models/trip_status.dart';
import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_operational_read_result.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_operational_reader.dart';

void main() {
  final createdAt = DateTime(2026, 9, 29, 10, 0);

  TripModel trip() {
    return TripModel(
      id: 'passenger-trip-1',
      passengerId: 'passenger-1',
      driverId: 'driver-1',
      pickupPoint: 'الدوار الأول',
      dropoffPoint: 'الجامعة الأردنية',
      createdAt: createdAt,
      status: TripStatus.active,
    );
  }

  VehicleTrip vehicle({
    double? routeProgress = 0.42,
    String driverId = 'driver-1',
  }) {
    return VehicleTrip(
      id: 'vehicle-trip-1',
      driverId: driverId,
      busNumber: 'BUS-01',
      routeId: 'route-1',
      direction: 'outbound',
      status: VehicleTripStatus.active,
      routeProgress: routeProgress,
    );
  }

  LiveDriverLocation liveLocation({
    String driverId = 'driver-1',
    double latitude = 31.95,
    double longitude = 35.91,
  }) {
    return LiveDriverLocation(
      driverId: driverId,
      fullName: 'سائق',
      latitude: latitude,
      longitude: longitude,
      heading: 90,
      speed: 12.5,
      isOnline: true,
      isTripActive: true,
      updatedAt: createdAt,
    );
  }

  PlannedRoute route({
    PlannedRouteStatus status = PlannedRouteStatus.approved,
    List<RoutePoint>? points,
  }) {
    return PlannedRoute(
      id: 'route-1',
      createdBy: 'admin-1',
      lineName: 'خط 1',
      direction: RouteDirection.outbound,
      points: points ??
          [
            RoutePoint(latitude: 31.95, longitude: 35.91, timestamp: createdAt),
            RoutePoint(latitude: 31.96, longitude: 35.92, timestamp: createdAt),
          ],
      status: status,
    );
  }

  BusWatchOperationalReader buildReader({
    Future<TripModel?> Function(String)? passengerTrip,
    Future<VehicleTrip?> Function(String)? activeVehicleTrip,
    Future<LiveDriverLocation?> Function(String)? liveLocationReader,
    Future<PlannedRoute?> Function(String)? plannedRoute,
  }) {
    return BusWatchOperationalReader(
      readPassengerTrip: passengerTrip ?? (_) async => trip(),
      readActiveVehicleTrip: activeVehicleTrip ?? (_) async => vehicle(),
      readLiveLocation: liveLocationReader ?? (_) async => liveLocation(),
      readPlannedRoute: plannedRoute ?? (_) async => route(),
    );
  }

  group('BusWatchOperationalReadResult contract', () {
    test('available requires a snapshot and unavailable has no snapshot', () {
      final snapshot = BusWatchOperationalSnapshot(
        passengerTripId: 'p-trip',
        vehicleTripId: 'v-trip',
        driverId: 'driver-1',
        busNumber: 'BUS-01',
        routeId: 'route-1',
        direction: 'outbound',
        status: VehicleTripStatus.active,
        liveLocation: liveLocation(),
        speed: 12.5,
        heading: 90,
        routeProgress: 0.5,
        lastLocationAt: createdAt,
        approvedRoute: route(),
      );

      final available = BusWatchOperationalReadResult.available(snapshot);
      final missing = BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noLiveLocation,
      );

      expect(available.status, BusWatchOperationalReadStatus.available);
      expect(available.snapshot, same(snapshot));
      expect(missing.status, BusWatchOperationalReadStatus.noLiveLocation);
      expect(missing.snapshot, isNull);
    });

    test('unavailable factory rejects available status', () {
      expect(
        () => BusWatchOperationalReadResult.unavailable(
          BusWatchOperationalReadStatus.available,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BusWatchOperationalReader absence statuses', () {
    test('missing Passenger context returns noPassengerContext', () async {
      var tripReads = 0;
      final reader = buildReader(
        passengerTrip: (_) async {
          tripReads++;
          return trip();
        },
      );

      final result = await reader.read(passengerTripId: '   ');

      expect(result.status, BusWatchOperationalReadStatus.noPassengerContext);
      expect(result.snapshot, isNull);
      expect(tripReads, 0);
    });

    test('missing Passenger Trip returns noPassengerContext', () async {
      final reader = buildReader(
        passengerTrip: (_) async => null,
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.noPassengerContext);
      expect(result.snapshot, isNull);
    });

    test('missing active VehicleTrip returns noActiveVehicleTrip', () async {
      final reader = buildReader(
        activeVehicleTrip: (_) async => null,
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(
        result.status,
        BusWatchOperationalReadStatus.noActiveVehicleTrip,
      );
      expect(result.snapshot, isNull);
    });

    test('mismatched active VehicleTrip driver returns noActiveVehicleTrip',
        () async {
      final reader = buildReader(
        activeVehicleTrip: (_) async => vehicle(driverId: 'driver-2'),
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(
        result.status,
        BusWatchOperationalReadStatus.noActiveVehicleTrip,
      );
      expect(result.snapshot, isNull);
    });

    test('missing live location returns noLiveLocation', () async {
      final reader = buildReader(
        liveLocationReader: (_) async => null,
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.noLiveLocation);
      expect(result.snapshot, isNull);
    });

    test('invalid live location returns noLiveLocation', () async {
      final reader = buildReader(
        liveLocationReader: (_) async =>
            liveLocation(latitude: 0, longitude: 0),
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.noLiveLocation);
      expect(result.snapshot, isNull);
    });

    test('missing PlannedRoute returns noApprovedRoute', () async {
      final reader = buildReader(
        plannedRoute: (_) async => null,
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.noApprovedRoute);
      expect(result.snapshot, isNull);
    });

    test('unapproved PlannedRoute returns noApprovedRoute', () async {
      final reader = buildReader(
        plannedRoute: (_) async => route(status: PlannedRouteStatus.pending),
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.noApprovedRoute);
      expect(result.snapshot, isNull);
    });

    test('invalid route geometry returns noApprovedRoute', () async {
      final reader = buildReader(
        plannedRoute: (_) async => route(
          points: [
            RoutePoint(
              latitude: 31.95,
              longitude: 35.91,
              timestamp: createdAt,
            ),
          ],
        ),
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.noApprovedRoute);
      expect(result.snapshot, isNull);
    });
  });

  group('BusWatchOperationalReader available result', () {
    test('builds one operational snapshot from the required sources', () async {
      final reader = buildReader();

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.available);
      final snapshot = result.snapshot!;
      expect(snapshot.passengerTripId, 'passenger-trip-1');
      expect(snapshot.vehicleTripId, 'vehicle-trip-1');
      expect(snapshot.driverId, 'driver-1');
      expect(snapshot.busNumber, 'BUS-01');
      expect(snapshot.routeId, 'route-1');
      expect(snapshot.direction, 'outbound');
      expect(snapshot.status, VehicleTripStatus.active);
      expect(snapshot.liveLocation.latitude, 31.95);
      expect(snapshot.liveLocation.longitude, 35.91);
      expect(snapshot.speed, 12.5);
      expect(snapshot.heading, 90);
      expect(snapshot.lastLocationAt, createdAt);
      expect(snapshot.approvedRoute.id, 'route-1');
      expect(snapshot.approvedRoute.isApproved, isTrue);
      expect(snapshot.approvedRoute.points.length, 2);
    });

    test('keeps VehicleTrip.routeProgress as operational data only', () async {
      final reader = buildReader(
        activeVehicleTrip: (_) async => vehicle(routeProgress: 0.73),
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.available);
      expect(result.snapshot!.routeProgress, 0.73);
    });

    test('resolves PlannedRoute by exact VehicleTrip.routeId', () async {
      var requestedRouteId = '';
      final reader = buildReader(
        plannedRoute: (routeId) async {
          requestedRouteId = routeId;
          return route();
        },
      );

      final result = await reader.read(passengerTripId: 'passenger-trip-1');

      expect(result.status, BusWatchOperationalReadStatus.available);
      expect(requestedRouteId, 'route-1');
    });
  });
}
