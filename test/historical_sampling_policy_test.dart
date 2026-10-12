import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:jordan_bus_tracker_new/services/historical_sampling_policy.dart';

Position _position(DateTime timestamp) {
  return Position(
    longitude: 35.91,
    latitude: 31.95,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 10,
    speedAccuracy: 1,
  );
}

void main() {
  group('HistoricalSamplingPolicy', () {
    final now = DateTime.utc(2026, 9, 26, 20, 0, 0);

    test('accepts a fresh GPS fix', () {
      expect(
        HistoricalSamplingPolicy.isFresh(
          _position(now.subtract(const Duration(seconds: 10))),
          now: now,
        ),
        isTrue,
      );
    });

    test('accepts a fix exactly at the maximum age', () {
      expect(
        HistoricalSamplingPolicy.isFresh(
          _position(
            now.subtract(HistoricalSamplingPolicy.maxPositionAge),
          ),
          now: now,
        ),
        isTrue,
      );
    });

    test('rejects an old cached fix', () {
      expect(
        HistoricalSamplingPolicy.isFresh(
          _position(now.subtract(const Duration(seconds: 46))),
          now: now,
        ),
        isFalse,
      );
    });

    test('rejects a future-dated fix', () {
      expect(
        HistoricalSamplingPolicy.isFresh(
          _position(now.add(const Duration(seconds: 1))),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
