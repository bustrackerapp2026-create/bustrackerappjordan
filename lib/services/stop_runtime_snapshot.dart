import '../services/next_stop_resolver.dart';
import '../services/stop_state_resolver.dart';

/// Runtime-derived view of fixed route stops for one accepted vehicle position.
///
/// This is in-memory only. It is not persisted to Firestore.
class StopRuntimeSnapshot {
  final List<ProjectedPlannedRouteStop> eligibleProjectedStops;
  final ProjectedPlannedRouteStop? nextStop;
  final Map<String, StopState> statesByStopId;

  StopRuntimeSnapshot({
    required List<ProjectedPlannedRouteStop> eligibleProjectedStops,
    required this.nextStop,
    required Map<String, StopState> statesByStopId,
  })  : eligibleProjectedStops =
            List<ProjectedPlannedRouteStop>.unmodifiable(eligibleProjectedStops),
        statesByStopId = Map<String, StopState>.unmodifiable(statesByStopId);
}
