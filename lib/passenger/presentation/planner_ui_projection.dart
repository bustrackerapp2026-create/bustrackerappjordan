import '../../services/passenger_journey_presentation_state.dart';

/// UI-only projection of the latest Planner request state.
///
/// This contract carries presentation state only. It does not own or expose
/// Journey Options, PlannedRoute snapshots, Mapbox state, or rendering results.
enum PlannerUiProjectionStatus {
  idle,
  loading,
  success,
  empty,
  error,
}

class PlannerUiProjection {
  const PlannerUiProjection._(this.status);

  final PlannerUiProjectionStatus status;

  factory PlannerUiProjection.fromState(
    PassengerJourneyPresentationState state,
  ) {
    final status = switch (state.status) {
      PassengerJourneyPresentationStatus.idle =>
        PlannerUiProjectionStatus.idle,
      PassengerJourneyPresentationStatus.loading =>
        PlannerUiProjectionStatus.loading,
      PassengerJourneyPresentationStatus.success =>
        PlannerUiProjectionStatus.success,
      PassengerJourneyPresentationStatus.empty =>
        PlannerUiProjectionStatus.empty,
      PassengerJourneyPresentationStatus.error =>
        PlannerUiProjectionStatus.error,
    };

    return PlannerUiProjection._(status);
  }
}
