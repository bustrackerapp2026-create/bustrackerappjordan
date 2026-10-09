import 'bus_watch_operational_consumer.dart';
import 'bus_watch_operational_read_result.dart';
import 'bus_watch_operational_reader.dart';

typedef BusWatchOperationalReadRequest = Future<
    BusWatchOperationalReadResult> Function(String passengerTripId);

/// Owns the lifecycle of one Passenger Trip's BusWatch operational reads.
///
/// The coordinator controls when a read starts and whether its result/error
/// still belongs to the active context generation. It does not select trips,
/// retain operational snapshots, poll, schedule, or stream.
class BusWatchReadLifecycleCoordinator {
  final BusWatchOperationalConsumer _consumer;
  final BusWatchOperationalReadRequest _read;

  String? _currentTripId;
  int _generation = 0;

  BusWatchReadLifecycleCoordinator({
    BusWatchOperationalConsumer? consumer,
    BusWatchOperationalReadRequest? read,
  })  : _consumer = consumer ?? BusWatchOperationalConsumer(),
        _read = read ??
            ((passengerTripId) => BusWatchOperationalReader().read(
                  passengerTripId: passengerTripId,
                ));

  BusWatchOperationalConsumer get consumer => _consumer;

  String? get currentTripId => _currentTripId;

  /// Binds the coordinator to one exact Passenger Trip context and starts
  /// exactly one initial read for that context.
  Future<void> bind(String tripId) {
    final normalizedTripId = tripId.trim();

    _generation++;
    final generation = _generation;
    _currentTripId = normalizedTripId.isEmpty ? null : normalizedTripId;
    _consumer.clear();

    if (_currentTripId == null) {
      return Future<void>.value();
    }

    return _readForCurrentContext(generation, _currentTripId!);
  }

  /// Re-reads the same currently bound Passenger Trip.
  ///
  /// No alternate trip can be selected here. When no context is bound, this
  /// is a no-op.
  Future<void> refresh() {
    final tripId = _currentTripId;
    if (tripId == null) {
      return Future<void>.value();
    }

    final generation = _generation;
    return _readForCurrentContext(generation, tripId);
  }

  /// Invalidates the current context and clears Consumer state.
  ///
  /// Any result or error belonging to the previous generation is discarded.
  void clear() {
    _generation++;
    _currentTripId = null;
    _consumer.clear();
  }

  Future<void> _readForCurrentContext(
    int generation,
    String tripId,
  ) async {
    try {
      final result = await _read(tripId);
      if (_isCurrent(generation, tripId)) {
        _consumer.consume(result);
      }
    } catch (error, stackTrace) {
      if (_isCurrent(generation, tripId)) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  bool _isCurrent(int generation, String tripId) =>
      _generation == generation && _currentTripId == tripId;
}
