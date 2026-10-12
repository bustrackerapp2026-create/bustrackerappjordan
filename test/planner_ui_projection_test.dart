import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/passenger/presentation/planner_ui_projection.dart';
import 'package:jordan_bus_tracker_new/services/passenger_journey_presentation_state.dart';

void main() {
  PlannerUiProjection project(
    PassengerJourneyPresentationState state,
  ) {
    return PlannerUiProjection.fromState(state);
  }

  test('idle projects to idle', () {
    final state = PassengerJourneyPresentationState();

    expect(
      project(state).status,
      PlannerUiProjectionStatus.idle,
    );
  });

  test('loading projects to loading', () {
    final state = PassengerJourneyPresentationState();

    state.beginLoading();

    expect(
      project(state).status,
      PlannerUiProjectionStatus.loading,
    );
  });

  test('loading transitions to success without route data in projection', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();

    expect(
      project(state).status,
      PlannerUiProjectionStatus.loading,
    );

    state.completeSuccess(generation);

    expect(
      project(state).status,
      PlannerUiProjectionStatus.success,
    );
  });

  test('loading transitions to empty without clearing route ownership', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();

    state.completeEmpty(generation);

    expect(
      project(state).status,
      PlannerUiProjectionStatus.empty,
    );
  });

  test('loading transitions to error', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();

    state.completeError(generation, StateError('planner failed'));

    expect(
      project(state).status,
      PlannerUiProjectionStatus.error,
    );
  });

  test('success transitions to loading for the next request', () {
    final state = PassengerJourneyPresentationState();
    final firstGeneration = state.beginLoading();

    state.completeSuccess(firstGeneration);

    expect(
      project(state).status,
      PlannerUiProjectionStatus.success,
    );

    state.beginLoading();

    expect(
      project(state).status,
      PlannerUiProjectionStatus.loading,
    );
  });
}
