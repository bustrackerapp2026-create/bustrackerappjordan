import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/services/bus_watch_operational_consumer.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_operational_read_result.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_read_lifecycle_coordinator.dart';

void main() {
  BusWatchOperationalReadResult resultFor(String tripId) {
    return BusWatchOperationalReadResult.unavailable(
      tripId == 'A'
          ? BusWatchOperationalReadStatus.noLiveLocation
          : BusWatchOperationalReadStatus.noApprovedRoute,
    );
  }

  group('BusWatchReadLifecycleCoordinator', () {
    test('bind starts one initial read and consumes its result', () async {
      var reads = 0;

      final coordinator = BusWatchReadLifecycleCoordinator(
        read: (tripId) async {
          reads++;
          return resultFor(tripId);
        },
      );

      await coordinator.bind('A');

      expect(reads, 1);
      expect(coordinator.currentTripId, 'A');
      expect(
        coordinator.consumer.status,
        BusWatchOperationalReadStatus.noLiveLocation,
      );
    });

    test('bind A then explicit refresh reads A again', () async {
      final requestedTripIds = <String>[];

      final coordinator = BusWatchReadLifecycleCoordinator(
        read: (tripId) async {
          requestedTripIds.add(tripId);
          return resultFor(tripId);
        },
      );

      await coordinator.bind('A');
      await coordinator.refresh();

      expect(requestedTripIds, ['A', 'A']);
      expect(coordinator.currentTripId, 'A');
    });

    test('late result from A is rejected after binding B', () async {
      final aRead = Completer<BusWatchOperationalReadResult>();

      final coordinator = BusWatchReadLifecycleCoordinator(
        read: (tripId) {
          if (tripId == 'A') {
            return aRead.future;
          }
          return Future.value(resultFor('B'));
        },
      );

      final bindA = coordinator.bind('A');
      await coordinator.bind('B');

      aRead.complete(resultFor('A'));
      await bindA;

      expect(coordinator.currentTripId, 'B');
      expect(
        coordinator.consumer.status,
        BusWatchOperationalReadStatus.noApprovedRoute,
      );
    });

    test('late error from A is rejected after binding B', () async {
      final aRead = Completer<BusWatchOperationalReadResult>();

      final coordinator = BusWatchReadLifecycleCoordinator(
        read: (tripId) {
          if (tripId == 'A') {
            return aRead.future;
          }
          return Future.value(resultFor('B'));
        },
      );

      final bindA = coordinator.bind('A');
      await coordinator.bind('B');

      aRead.completeError(StateError('late A error'));
      await expectLater(bindA, completes);

      expect(coordinator.currentTripId, 'B');
      expect(
        coordinator.consumer.status,
        BusWatchOperationalReadStatus.noApprovedRoute,
      );
    });

    test('late result is rejected after clear', () async {
      final read = Completer<BusWatchOperationalReadResult>();

      final coordinator = BusWatchReadLifecycleCoordinator(
        read: (_) => read.future,
      );

      final bindA = coordinator.bind('A');
      coordinator.clear();

      read.complete(resultFor('A'));
      await bindA;

      expect(coordinator.currentTripId, isNull);
      expect(coordinator.consumer.currentResult, isNull);
    });

    test('reactivation by rebinding the exact trip starts a new read', () async {
      var reads = 0;

      final coordinator = BusWatchReadLifecycleCoordinator(
        read: (tripId) async {
          reads++;
          return resultFor(tripId);
        },
      );

      await coordinator.bind('A');
      coordinator.clear();
      await coordinator.bind('A');

      expect(reads, 2);
      expect(coordinator.currentTripId, 'A');
    });

    test('same tripId plus explicit refresh produces a fresh read', () async {
      var reads = 0;

      final coordinator = BusWatchReadLifecycleCoordinator(
        read: (tripId) async {
          reads++;
          return resultFor(tripId);
        },
      );

      await coordinator.bind('A');
      await coordinator.refresh();

      expect(reads, 2);
    });
  });
}
