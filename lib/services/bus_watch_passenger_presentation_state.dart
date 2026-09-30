import 'bus_watch_operational_read_result.dart';

/// Mutable presentation-only state for the Passenger BusWatch bridge.
///
/// This is not a domain model and does not own reads. MapTab owns one
/// instance and uses the generation token to reject stale async completions.
class BusWatchPassengerPresentationState {
  String? _contextTripId;
  bool _loading = false;
  BusWatchOperationalReadResult? _result;
  Object? _error;
  int _generation = 0;

  String? get contextTripId => _contextTripId;
  bool get loading => _loading;
  BusWatchOperationalReadResult? get result => _result;
  Object? get error => _error;

  int beginContext(String tripId) {
    _generation++;
    _contextTripId = tripId;
    _loading = true;
    _result = null;
    _error = null;
    return _generation;
  }

  int beginRefresh(String tripId) {
    _generation++;
    _contextTripId = tripId;
    _loading = true;
    _error = null;
    return _generation;
  }

  bool isCurrent(int generation, String tripId) =>
      _generation == generation && _contextTripId == tripId;

  void complete(
    int generation,
    String tripId,
    BusWatchOperationalReadResult result,
  ) {
    if (!isCurrent(generation, tripId)) return;
    _loading = false;
    _result = result;
    _error = null;
  }

  void fail(
    int generation,
    String tripId,
    Object error,
  ) {
    if (!isCurrent(generation, tripId)) return;
    _generation++;
    _loading = false;
    _result = null;
    _error = error;
  }

  void clear() {
    _generation++;
    _contextTripId = null;
    _loading = false;
    _result = null;
    _error = null;
  }
}
