import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/trip_status.dart';

void main() {
  group('TripStatusExtension', () {
    test('stringValue maps each status correctly', () {
      expect(TripStatus.pending.stringValue, 'pending');
      expect(TripStatus.active.stringValue, 'active');
      expect(TripStatus.completed.stringValue, 'completed');
      expect(TripStatus.cancelled.stringValue, 'cancelled');
    });

    test('fromString maps known values', () {
      expect(TripStatusExtension.fromString('pending'), TripStatus.pending);
      expect(TripStatusExtension.fromString('active'), TripStatus.active);
      expect(TripStatusExtension.fromString('completed'), TripStatus.completed);
      expect(TripStatusExtension.fromString('cancelled'), TripStatus.cancelled);
    });

    test('fromString falls back to pending for unknown values', () {
      expect(TripStatusExtension.fromString('unknown'), TripStatus.pending);
      expect(TripStatusExtension.fromString(''), TripStatus.pending);
    });

    test('round-trip stringValue -> fromString', () {
      for (final status in TripStatus.values) {
        expect(
          TripStatusExtension.fromString(status.stringValue),
          status,
        );
      }
    });
  });
}
