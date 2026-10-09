import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/services/bus_watch_operational_read_result.dart';
import 'package:jordan_bus_tracker_new/services/bus_watch_passenger_presentation_state.dart';

void main() {
  BusWatchOperationalReadResult resultFor(
    BusWatchOperationalReadStatus status,
  ) {
    return BusWatchOperationalReadResult.unavailable(status);
  }

  group('BusWatchPassengerPresentationState', () {
    test('beginContext starts loading for the exact context', () {
      final state = BusWatchPassengerPresentationState();

      final generation = state.beginContext('A');

      expect(generation, 1);
      expect(state.contextTripId, 'A');
      expect(state.loading, isTrue);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('complete applies only to the current generation and context', () {
      final state = BusWatchPassengerPresentationState();
      final generation = state.beginContext('A');
      final result =
          resultFor(BusWatchOperationalReadStatus.noLiveLocation);

      state.complete(generation, 'A', result);

      expect(state.loading, isFalse);
      expect(state.result, same(result));
      expect(state.error, isNull);
    });

    test('stale completion cannot change the current context', () {
      final state = BusWatchPassengerPresentationState();
      final generationA = state.beginContext('A');
      final generationB = state.beginContext('B');
      final resultA =
          resultFor(BusWatchOperationalReadStatus.noLiveLocation);

      state.complete(generationA, 'A', resultA);

      expect(state.contextTripId, 'B');
      expect(state.loading, isTrue);
      expect(state.result, isNull);
      expect(state.error, isNull);
      expect(state.isCurrent(generationB, 'B'), isTrue);
    });

    test('stale error cannot change the current context', () {
      final state = BusWatchPassengerPresentationState();
      final generationA = state.beginContext('A');
      state.beginContext('B');

      state.fail(generationA, 'A', StateError('late A'));

      expect(state.contextTripId, 'B');
      expect(state.loading, isTrue);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('retry keeps old result during loading and accepts the new result', () {
      final state = BusWatchPassengerPresentationState();
      final firstGeneration = state.beginContext('A');
      final oldResult =
          resultFor(BusWatchOperationalReadStatus.noApprovedRoute);
      state.complete(firstGeneration, 'A', oldResult);

      final refreshGeneration = state.beginRefresh('A');

      expect(state.contextTripId, 'A');
      expect(state.loading, isTrue);
      expect(state.result, same(oldResult));
      expect(state.error, isNull);

      final newResult =
          resultFor(BusWatchOperationalReadStatus.noLiveLocation);
      state.complete(refreshGeneration, 'A', newResult);

      expect(state.loading, isFalse);
      expect(state.result, same(newResult));
      expect(state.error, isNull);
      expect(state.contextTripId, 'A');
    });

    test('fail clears result and preserves infrastructure error', () {
      final state = BusWatchPassengerPresentationState();
      final generation = state.beginContext('A');
      final result =
          resultFor(BusWatchOperationalReadStatus.noLiveLocation);
      state.complete(generation, 'A', result);

      final refreshGeneration = state.beginRefresh('A');
      final error = StateError('read failed');

      state.fail(refreshGeneration, 'A', error);

      expect(state.contextTripId, 'A');
      expect(state.loading, isFalse);
      expect(state.result, isNull);
      expect(state.error, same(error));
    });

    test('clear invalidates the active generation and clears all state', () {
      final state = BusWatchPassengerPresentationState();
      final generation = state.beginContext('A');
      state.clear();

      state.complete(
        generation,
        'A',
        resultFor(BusWatchOperationalReadStatus.noLiveLocation),
      );

      expect(state.contextTripId, isNull);
      expect(state.loading, isFalse);
      expect(state.result, isNull);
      expect(state.error, isNull);
      expect(state.isCurrent(generation, 'A'), isFalse);
    });
  });
}
