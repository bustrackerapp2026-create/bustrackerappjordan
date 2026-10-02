import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/passenger_journey_presentation_state.dart';

void main() {
  PlannedRoute route(String id) {
    return PlannedRoute(
      id: id,
      createdBy: 'test',
      lineName: 'Test',
      direction: RouteDirection.outbound,
      points: const [
        RoutePoint(latitude: 31.90, longitude: 35.90),
        RoutePoint(latitude: 31.90, longitude: 35.91),
      ],
      status: PlannedRouteStatus.approved,
    );
  }

  test('starts idle with no planner-owned display', () {
    final state = PassengerJourneyPresentationState();

    expect(state.status, PassengerJourneyPresentationStatus.idle);
    expect(state.error, isNull);
    expect(state.plannerDisplayedRoutes, isEmpty);
  });

  test('loading preserves the previous planner-owned display', () {
    final state = PassengerJourneyPresentationState();
    final generationA = state.beginLoading();
    final first = route('route-a');

    state.completeSuccess(generationA, [first]);
    final generationB = state.beginLoading();

    expect(state.status, PassengerJourneyPresentationStatus.loading);
    expect(state.plannerDisplayedRoutes, [first]);
    expect(state.isCurrent(generationB), isTrue);
  });

  test('success replaces the planner-owned display', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();
    final first = route('route-a');
    final second = route('route-b');

    state.completeSuccess(generation, [second]);

    expect(state.status, PassengerJourneyPresentationStatus.success);
    expect(state.plannerDisplayedRoutes, [second]);
    expect(state.plannerDisplayedRoutes.single, same(second));
    expect(state.plannerDisplayedRoutes.contains(first), isFalse);
  });

  test('empty clears the planner-owned display', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();
    state.completeSuccess(generation, [route('route-a')]);

    final refresh = state.beginLoading();
    state.completeEmpty(refresh);

    expect(state.status, PassengerJourneyPresentationStatus.empty);
    expect(state.plannerDisplayedRoutes, isEmpty);
  });

  test('error clears the planner-owned display and keeps the error', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();
    state.completeSuccess(generation, [route('route-a')]);

    final refresh = state.beginLoading();
    final error = StateError('read failed');
    state.completeError(refresh, error);

    expect(state.status, PassengerJourneyPresentationStatus.error);
    expect(state.error, same(error));
    expect(state.plannerDisplayedRoutes, isEmpty);
  });

  test('stale success cannot replace the current request', () {
    final state = PassengerJourneyPresentationState();
    final generationA = state.beginLoading();
    final generationB = state.beginLoading();
    final routeB = route('route-b');

    state.completeSuccess(generationA, [route('route-a')]);

    expect(state.status, PassengerJourneyPresentationStatus.loading);
    expect(state.isCurrent(generationB), isTrue);
    expect(state.plannerDisplayedRoutes, isEmpty);

    state.completeSuccess(generationB, [routeB]);

    expect(state.status, PassengerJourneyPresentationStatus.success);
    expect(state.plannerDisplayedRoutes.single, same(routeB));
  });

  test('stale empty cannot clear a newer success', () {
    final state = PassengerJourneyPresentationState();
    final generationA = state.beginLoading();
    final generationB = state.beginLoading();
    final routeB = route('route-b');

    state.completeSuccess(generationB, [routeB]);
    state.completeEmpty(generationA);

    expect(state.status, PassengerJourneyPresentationStatus.success);
    expect(state.plannerDisplayedRoutes.single, same(routeB));
  });

  test('stale error cannot clear a newer success', () {
    final state = PassengerJourneyPresentationState();
    final generationA = state.beginLoading();
    final generationB = state.beginLoading();
    final routeB = route('route-b');

    state.completeSuccess(generationB, [routeB]);
    state.completeError(generationA, StateError('late A'));

    expect(state.status, PassengerJourneyPresentationStatus.success);
    expect(state.error, isNull);
    expect(state.plannerDisplayedRoutes.single, same(routeB));
  });

  test('clear invalidates the current request', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();
    state.completeSuccess(generation, [route('route-a')]);

    state.clear();
    state.completeEmpty(generation);

    expect(state.status, PassengerJourneyPresentationStatus.idle);
    expect(state.error, isNull);
    expect(state.plannerDisplayedRoutes, isEmpty);
    expect(state.isCurrent(generation), isFalse);
  });

  test('display snapshot is an independent unmodifiable copy', () {
    final state = PassengerJourneyPresentationState();
    final generation = state.beginLoading();
    final routes = [route('route-a')];

    state.completeSuccess(generation, routes);
    routes.add(route('route-b'));

    expect(state.plannerDisplayedRoutes, hasLength(1));
    expect(
      () => state.plannerDisplayedRoutes.add(route('route-c')),
      throwsUnsupportedError,
    );
  });
}
