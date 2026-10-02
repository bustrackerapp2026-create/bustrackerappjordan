import '../models/planned_route.dart';

enum PassengerJourneyPresentationStatus {
  idle,
  loading,
  success,
  empty,
  error,
}

/// Pure presentation state for the latest passenger journey-planning request.
///
/// It owns no Mapbox objects, performs no I/O, and uses a generation token
/// so stale async completions cannot mutate the current Planner state.
class PassengerJourneyPresentationState {
  int _generation = 0;
  PassengerJourneyPresentationStatus _status =
      PassengerJourneyPresentationStatus.idle;
  Object? _error;
  List<PlannedRoute> _plannerDisplayedRoutes = const [];

  PassengerJourneyPresentationStatus get status => _status;
  Object? get error => _error;
  List<PlannedRoute> get plannerDisplayedRoutes =>
      List<PlannedRoute>.unmodifiable(_plannerDisplayedRoutes);

  int beginLoading() {
    _generation++;
    _status = PassengerJourneyPresentationStatus.loading;
    _error = null;
    return _generation;
  }

  bool isCurrent(int generation) => _generation == generation;

  void completeSuccess(
    int generation,
    List<PlannedRoute> routes,
  ) {
    if (!isCurrent(generation)) return;
    _status = PassengerJourneyPresentationStatus.success;
    _error = null;
    _plannerDisplayedRoutes = List<PlannedRoute>.unmodifiable(routes);
  }

  void completeEmpty(int generation) {
    if (!isCurrent(generation)) return;
    _status = PassengerJourneyPresentationStatus.empty;
    _error = null;
    _plannerDisplayedRoutes = const [];
  }

  void completeError(int generation, Object error) {
    if (!isCurrent(generation)) return;
    _status = PassengerJourneyPresentationStatus.error;
    _error = error;
    _plannerDisplayedRoutes = const [];
  }

  void clear() {
    _generation++;
    _status = PassengerJourneyPresentationStatus.idle;
    _error = null;
    _plannerDisplayedRoutes = const [];
  }
}
