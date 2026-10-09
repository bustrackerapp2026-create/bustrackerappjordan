enum PassengerJourneyPresentationStatus {
  idle,
  loading,
  success,
  empty,
  error,
}

/// Pure presentation state for the latest passenger journey-planning request.
///
/// It owns no route snapshot, Mapbox objects, or I/O. A generation token
/// prevents stale async completions from mutating the current Planner state.
class PassengerJourneyPresentationState {
  int _generation = 0;
  PassengerJourneyPresentationStatus _status =
      PassengerJourneyPresentationStatus.idle;
  Object? _error;

  PassengerJourneyPresentationStatus get status => _status;
  Object? get error => _error;

  int beginLoading() {
    _generation++;
    _status = PassengerJourneyPresentationStatus.loading;
    _error = null;
    return _generation;
  }

  bool isCurrent(int generation) => _generation == generation;

  void completeSuccess(int generation) {
    if (!isCurrent(generation)) return;
    _status = PassengerJourneyPresentationStatus.success;
    _error = null;
  }

  void completeEmpty(int generation) {
    if (!isCurrent(generation)) return;
    _status = PassengerJourneyPresentationStatus.empty;
    _error = null;
  }

  void completeError(int generation, Object error) {
    if (!isCurrent(generation)) return;
    _status = PassengerJourneyPresentationStatus.error;
    _error = error;
  }

  void clear() {
    _generation++;
    _status = PassengerJourneyPresentationStatus.idle;
    _error = null;
  }
}
