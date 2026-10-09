import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/trip_model.dart';
import 'package:jordan_bus_tracker_new/models/trip_status.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_operational_read_result.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_passenger_context_binder.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_read_lifecycle_coordinator.dart';

void main() {
  TripModel trip(String id) {
    return TripModel(
      id: id,
      passengerId: 'passenger-1',
      driverId: 'driver-1',
      pickupPoint: 'الدوار الأول',
      dropoffPoint: 'الجامعة الأردنية',
      createdAt: DateTime(2026, 9, 30, 10),
      status: TripStatus.active,
    );
  }

  BusWatchOperationalReadResult resultFor(String tripId) {
    return BusWatchOperationalReadResult.unavailable(
      tripId == 'A'
          ? BusWatchOperationalReadStatus.noLiveLocation
          : BusWatchOperationalReadStatus.noApprovedRoute,
    );
  }

  group('BusWatchPassengerContextBinder', () {
    test('sync binds the exact selected TripModel.id', () async {
      final requestedTripIds = <String>[];

      final binder = BusWatchPassengerContextBinder(
        coordinator: BusWatchReadLifecycleCoordinator(
          read: (tripId) async {
            requestedTripIds.add(tripId);
            return resultFor(tripId);
          },
        ),
      );

      await binder.sync(trip(' A '));

      expect(requestedTripIds, ['A']);
      expect(binder.currentTripId, 'A');
      expect(binder.coordinator.currentTripId, 'A');
    });

    test('syncing the same Trip does not start another read', () async {
      var reads = 0;

      final binder = BusWatchPassengerContextBinder(
        coordinator: BusWatchReadLifecycleCoordinator(
          read: (tripId) async {
            reads++;
            return resultFor(tripId);
          },
        ),
      );

      await binder.sync(trip('A'));
      await binder.sync(trip('A'));

      expect(reads, 1);
      expect(binder.currentTripId, 'A');
    });

    test('changing the selected Trip binds the new exact id', () async {
      final requestedTripIds = <String>[];

      final binder = BusWatchPassengerContextBinder(
        coordinator: BusWatchReadLifecycleCoordinator(
          read: (tripId) async {
            requestedTripIds.add(tripId);
            return resultFor(tripId);
          },
        ),
      );

      await binder.sync(trip('A'));
      await binder.sync(trip('B'));

      expect(requestedTripIds, ['A', 'B']);
      expect(binder.currentTripId, 'B');
      expect(binder.coordinator.currentTripId, 'B');
    });

    test('late read from an old Trip remains rejected after context change',
        () async {
      final aRead = Completer<BusWatchOperationalReadResult>();

      final binder = BusWatchPassengerContextBinder(
        coordinator: BusWatchReadLifecycleCoordinator(
          read: (tripId) {
            if (tripId == 'A') {
              return aRead.future;
            }
            return Future.value(resultFor('B'));
          },
        ),
      );

      final bindA = binder.sync(trip('A'));
      await binder.sync(trip('B'));

      aRead.complete(resultFor('A'));
      await bindA;

      expect(binder.currentTripId, 'B');
      expect(
        binder.coordinator.consumer.status,
        BusWatchOperationalReadStatus.noApprovedRoute,
      );
    });

    test('sync with no selected Trip clears the current context', () async {
      final binder = BusWatchPassengerContextBinder(
        coordinator: BusWatchReadLifecycleCoordinator(
          read: (tripId) async => resultFor(tripId),
        ),
      );

      await binder.sync(trip('A'));
      await binder.sync(null);

      expect(binder.currentTripId, isNull);
      expect(binder.coordinator.currentTripId, isNull);
      expect(binder.coordinator.consumer.currentResult, isNull);
    });

    test('refresh re-reads only the currently bound Trip', () async {
      final requestedTripIds = <String>[];

      final binder = BusWatchPassengerContextBinder(
        coordinator: BusWatchReadLifecycleCoordinator(
          read: (tripId) async {
            requestedTripIds.add(tripId);
            return resultFor(tripId);
          },
        ),
      );

      await binder.sync(trip('A'));
      await binder.refresh();

      expect(requestedTripIds, ['A', 'A']);
      expect(binder.currentTripId, 'A');
    });

    test('sync with empty Trip id does not create a BusWatch context', () async {
      var reads = 0;

      final binder = BusWatchPassengerContextBinder(
        coordinator: BusWatchReadLifecycleCoordinator(
          read: (tripId) async {
            reads++;
            return resultFor(tripId);
          },
        ),
      );

      await binder.sync(trip('   '));

      expect(reads, 0);
      expect(binder.currentTripId, isNull);
      expect(binder.coordinator.currentTripId, isNull);
    });
  });
}
