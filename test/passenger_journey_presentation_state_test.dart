import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/services/passenger_journey_presentation_state.dart';

void main() {
  test('starts idle with no error', () {
    final state = PassengerJourneyPresentationState();

    expect(state.status, PassengerJourneyPresentationStatus.idle);
    expect(state.error, isNull);
  });

  test('beginLoading enters loading and advances generation', () {
    final state = PassengerJourneyPresentationState();

    final generation = state.beginLoading();

    expect(state.status, PassengerJourneyPresentationStatus.loading);
    expect(state.error, isNull);
    expect(state.isCurrent(generation), isTrue);
  });

  test(
    'success marks the current request without owning route data',
    () {
      final state = PassengerJourneyPresentationState();
      final generation = state.beginLoading();

      state.completeSuccess(generation);

      expect(state.status, PassengerJourneyPresentationStatus.success);
      expect(state.error, isNull);
      expect(state.isCurrent(generation), isTrue);
    },
  );

  test('empty marks the current request as semantically empty', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();

    state.completeEmpty(generation);

    expect(state.status, PassengerJourneyPresentationStatus.empty);
    expect(state.error, isNull);
    expect(state.isCurrent(generation), isTrue);
  });

  test('error marks the current request as failed and preserves the error', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();
    final error = StateError('read failed');

    state.completeError(generation, error);

    expect(state.status, PassengerJourneyPresentationStatus.error);
    expect(state.error, same(error));
    expect(state.isCurrent(generation), isTrue);
  });

  test('Request B remains authoritative over stale Request A completion', () {
    final state = PassengerJourneyPresentationState();
    final generationA = state.beginLoading();
    final generationB = state.beginLoading();

    state.completeSuccess(generationA);

    expect(state.status, PassengerJourneyPresentationStatus.loading);
    expect(state.error, isNull);
    expect(state.isCurrent(generationB), isTrue);
    expect(state.isCurrent(generationA), isFalse);

    state.completeSuccess(generationB);

    expect(state.status, PassengerJourneyPresentationStatus.success);
    expect(state.error, isNull);
    expect(state.isCurrent(generationB), isTrue);
  });

  test(
    'stale empty and error completions cannot overwrite a newer success',
    () {
      final state = PassengerJourneyPresentationState();
      final generationA = state.beginLoading();
      final generationB = state.beginLoading();

      state.completeSuccess(generationB);
      state.completeEmpty(generationA);

      expect(state.status, PassengerJourneyPresentationStatus.success);
      expect(state.error, isNull);

      state.completeError(generationA, StateError('late A'));

      expect(state.status, PassengerJourneyPresentationStatus.success);
      expect(state.error, isNull);
      expect(state.isCurrent(generationB), isTrue);
    },
  );

  test('clear invalidates the current generation and returns to idle', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();

    state.clear();
    state.completeSuccess(generation);
    state.completeError(generation, StateError('stale'));

    expect(state.status, PassengerJourneyPresentationStatus.idle);
    expect(state.error, isNull);
    expect(state.isCurrent(generation), isFalse);
  });

  test('clear also invalidates after a successful request', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();

    state.completeSuccess(generation);
    final newerGeneration = state.beginLoading();
    state.clear();

    expect(state.status, PassengerJourneyPresentationStatus.idle);
    expect(state.error, isNull);
    expect(state.isCurrent(generation), isFalse);
    expect(state.isCurrent(newerGeneration), isFalse);
  });
}
