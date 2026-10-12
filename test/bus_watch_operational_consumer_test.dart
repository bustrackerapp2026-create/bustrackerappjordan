import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/live_driver_location.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_operational_consumer.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_operational_read_result.dart';

void main() {
  LiveDriverLocation liveLocation(String driverId, double latitude) {
    return LiveDriverLocation(
      driverId: driverId,
      fullName: 'سائق',
      latitude: latitude,
      longitude: 35.91,
    );
  }

  PlannedRoute route(String id) {
    return PlannedRoute(
      id: id,
      createdBy: 'admin-1',
      lineName: 'خط 1',
      direction: RouteDirection.outbound,
      points: const [],
      status: PlannedRouteStatus.approved,
    );
  }

  BusWatchOperationalSnapshot snapshot({
    required String vehicleTripId,
    required String routeId,
    required double routeProgress,
    required double latitude,
  }) {
    return BusWatchOperationalSnapshot(
      passengerTripId: 'passenger-trip-1',
      vehicleTripId: vehicleTripId,
      driverId: 'driver-1',
      busNumber: 'BUS-01',
      routeId: routeId,
      direction: 'outbound',
      status: VehicleTripStatus.active,
      liveLocation: liveLocation('driver-1', latitude),
      speed: 10,
      heading: 90,
      routeProgress: routeProgress,
      lastLocationAt: DateTime(2026, 9, 29, 10),
      approvedRoute: routeId == 'route-1' ? route('route-1') : route('route-2'),
    );
  }

  group('BusWatchOperationalConsumer', () {
    test('starts without a Consumer result', () {
      final consumer = BusWatchOperationalConsumer();

      expect(consumer.currentResult, isNull);
      expect(consumer.status, isNull);
      expect(consumer.snapshot, isNull);
    });

    test('available result becomes the current Consumer state', () {
      final consumer = BusWatchOperationalConsumer();
      final snapshotValue = snapshot(
        vehicleTripId: 'vehicle-trip-1',
        routeId: 'route-1',
        routeProgress: 0.4,
        latitude: 31.95,
      );
      final result = BusWatchOperationalReadResult.available(snapshotValue);

      consumer.consume(result);

      expect(consumer.currentResult, same(result));
      expect(
        consumer.status,
        BusWatchOperationalReadStatus.available,
      );
      expect(consumer.snapshot, same(snapshotValue));
    });

    test('new available result fully replaces the previous state', () {
      final consumer = BusWatchOperationalConsumer();
      final first = BusWatchOperationalReadResult.available(
        snapshot(
          vehicleTripId: 'vehicle-trip-1',
          routeId: 'route-1',
          routeProgress: 0.4,
          latitude: 31.95,
        ),
      );
      final secondSnapshot = snapshot(
        vehicleTripId: 'vehicle-trip-2',
        routeId: 'route-2',
        routeProgress: 0.8,
        latitude: 31.97,
      );
      final second = BusWatchOperationalReadResult.available(secondSnapshot);

      consumer.consume(first);
      consumer.consume(second);

      expect(consumer.currentResult, same(second));
      expect(consumer.snapshot, same(secondSnapshot));
      expect(consumer.snapshot!.vehicleTripId, 'vehicle-trip-2');
      expect(consumer.snapshot!.routeId, 'route-2');
      expect(consumer.snapshot!.routeProgress, 0.8);
      expect(consumer.snapshot!.liveLocation.latitude, 31.97);
    });

    test('non-available result clears the previous operational snapshot', () {
      final consumer = BusWatchOperationalConsumer();
      final available = BusWatchOperationalReadResult.available(
        snapshot(
          vehicleTripId: 'vehicle-trip-1',
          routeId: 'route-1',
          routeProgress: 0.4,
          latitude: 31.95,
        ),
      );
      final unavailable = BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noLiveLocation,
      );

      consumer.consume(available);
      consumer.consume(unavailable);

      expect(consumer.currentResult, same(unavailable));
      expect(
        consumer.status,
        BusWatchOperationalReadStatus.noLiveLocation,
      );
      expect(consumer.snapshot, isNull);
    });

    test('noPassengerContext is consumed as-is without trip selection', () {
      final consumer = BusWatchOperationalConsumer();
      final result = BusWatchOperationalReadResult.unavailable(
        BusWatchOperationalReadStatus.noPassengerContext,
      );

      consumer.consume(result);

      expect(
        consumer.status,
        BusWatchOperationalReadStatus.noPassengerContext,
      );
      expect(consumer.snapshot, isNull);
    });

    test('clear removes the current result without creating a fallback', () {
      final consumer = BusWatchOperationalConsumer();
      final result = BusWatchOperationalReadResult.available(
        snapshot(
          vehicleTripId: 'vehicle-trip-1',
          routeId: 'route-1',
          routeProgress: 0.4,
          latitude: 31.95,
        ),
      );

      consumer.consume(result);
      consumer.clear();

      expect(consumer.currentResult, isNull);
      expect(consumer.status, isNull);
      expect(consumer.snapshot, isNull);
    });
  });
}
