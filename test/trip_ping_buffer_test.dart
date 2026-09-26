import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/trip_ping.dart';
import 'package:jordan_bus_tracker_new/services/trip_ping_service.dart';
import 'package:jordan_bus_tracker_new/services/trip_ping_buffer.dart';

TripPing _ping(int second) {
  return TripPing(
    tripId: 'trip-1',
    routeId: 'route-1',
    direction: 'outbound',
    location: GeoPoint(31.95 + second / 10000, 35.91),
    speed: 10 + second.toDouble(),
    heading: 90,
    timestamp: DateTime(2026, 9, 26, 13, 0, second),
  );
}

void main() {
  group('TripPing', () {
    test('accepts valid data and serializes to Firestore fields', () {
      final ping = _ping(1);

      expect(ping.isValid, isTrue);

      final data = ping.toFirestoreMap();
      expect(data['tripId'], 'trip-1');
      expect(data['routeId'], 'route-1');
      expect(data['direction'], 'outbound');
      expect(data['location'], ping.location);
      expect(data['speed'], 11);
      expect(data['heading'], 90);
      expect(data['timestamp'], isA<Timestamp>());
    });

    test('rejects invalid identifiers and direction', () {
      final ping = TripPing(
        tripId: '',
        routeId: '',
        direction: 'sideways',
        location: const GeoPoint(31, 35),
        timestamp: DateTime(2026, 9, 26),
      );

      expect(ping.isValid, isFalse);
      expect(() => ping.toFirestoreMap(), throwsA(isA<FormatException>()));
    });
  });

  group('TripPingBuffer', () {
    test('keeps insertion order and enforces max size', () {
      final buffer = TripPingBuffer(maxSize: 2);

      expect(buffer.tryAdd(_ping(1)), isTrue);
      expect(buffer.tryAdd(_ping(2)), isTrue);
      expect(buffer.isFull, isTrue);
      expect(buffer.tryAdd(_ping(3)), isFalse);

      expect(buffer.items.map((p) => p.timestamp.second), [1, 2]);
    });

    test('peekBatch does not remove items', () {
      final buffer = TripPingBuffer(maxSize: 5);
      buffer
        ..tryAdd(_ping(1))
        ..tryAdd(_ping(2));

      final batch = buffer.peekBatch(2);

      expect(batch.map((p) => p.timestamp.second), [1, 2]);
      expect(buffer.items.map((p) => p.timestamp.second), [1, 2]);
    });

    test('removeFirst removes only confirmed items', () {
      final buffer = TripPingBuffer(maxSize: 5);
      buffer
        ..tryAdd(_ping(1))
        ..tryAdd(_ping(2))
        ..tryAdd(_ping(3));

      buffer.removeFirst(2);

      expect(buffer.items.map((p) => p.timestamp.second), [3]);
    });

    test('takeBatch removes only the returned items', () {
      final buffer = TripPingBuffer(maxSize: 5);
      buffer
        ..tryAdd(_ping(1))
        ..tryAdd(_ping(2))
        ..tryAdd(_ping(3));

      final batch = buffer.takeBatch(2);

      expect(batch.map((p) => p.timestamp.second), [1, 2]);
      expect(buffer.items.map((p) => p.timestamp.second), [3]);
    });

    test('deterministic TripPing ids stay stable for retries', () {
      final ping = _ping(7);

      expect(
        TripPingService.docIdFor(ping),
        TripPingService.docIdFor(ping),
      );
      expect(
        TripPingService.docIdFor(ping),
        'trip-1_1758891616000000',
      );
    });

    test('drain returns all items and empties the buffer', () {
      final buffer = TripPingBuffer(maxSize: 5);
      buffer
        ..tryAdd(_ping(1))
        ..tryAdd(_ping(2));

      final drained = buffer.drain();

      expect(drained.map((p) => p.timestamp.second), [1, 2]);
      expect(buffer.isEmpty, isTrue);
    });
  });
}
