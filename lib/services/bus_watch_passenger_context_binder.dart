import '../models/trip_model.dart';
import 'bus_watch_read_lifecycle_coordinator.dart';

/// Binds the Passenger-selected Trip context to the BusWatch read lifecycle.
///
/// The caller remains responsible for selecting the Passenger Trip.
/// This binder only translates the selected Trip into its exact id and
/// coordinates bind/clear/refresh without selecting alternate trips.
class BusWatchPassengerContextBinder {
  final BusWatchReadLifecycleCoordinator _coordinator;

  String? _boundTripId;

  BusWatchPassengerContextBinder({
    BusWatchReadLifecycleCoordinator? coordinator,
  }) : _coordinator =
            coordinator ?? BusWatchReadLifecycleCoordinator();

  BusWatchReadLifecycleCoordinator get coordinator => _coordinator;

  String? get currentTripId => _boundTripId;

  /// Synchronizes the BusWatch context with the currently selected Passenger
  /// Trip. A different Trip starts a new coordinator generation; the same
  /// Trip is left untouched.
  Future<void> sync(TripModel? selectedTrip) {
    final tripId = selectedTrip?.id.trim() ?? '';

    if (tripId.isEmpty) {
      if (_boundTripId != null) {
        _boundTripId = null;
        _coordinator.clear();
      }
      return Future<void>.value();
    }

    if (_boundTripId == tripId) {
      return Future<void>.value();
    }

    _boundTripId = tripId;
    return _coordinator.bind(tripId);
  }

  /// Explicitly re-reads the currently bound Passenger Trip.
  Future<void> refresh() => _coordinator.refresh();

  /// Clears the Passenger BusWatch context.
  void clear() {
    if (_boundTripId == null) {
      return;
    }

    _boundTripId = null;
    _coordinator.clear();
  }
}
