import 'bus_watch_operational_read_result.dart';

/// Holds only the latest BusWatch operational read result for a Consumer.
///
/// The consumer does not select trips, perform reads, or retain historical
/// snapshots as a fallback. Each new result replaces the previous result.
class BusWatchOperationalConsumer {
  BusWatchOperationalReadResult? _currentResult;

  BusWatchOperationalReadResult? get currentResult => _currentResult;

  BusWatchOperationalReadStatus? get status => _currentResult?.status;

  BusWatchOperationalSnapshot? get snapshot => _currentResult?.snapshot;

  void consume(BusWatchOperationalReadResult result) {
    _currentResult = result;
  }

  void clear() {
    _currentResult = null;
  }
}
