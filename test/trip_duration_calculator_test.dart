import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/services/trip_duration_calculator.dart';

void main() {
  final startedAt = DateTime.utc(2026, 10, 3, 8, 15, 0);

  VehicleTrip trip({
    VehicleTripStatus status = VehicleTripStatus.completed,
    DateTime? started,
    DateTime? ended,
  }) {
    return VehicleTrip(
      id: 'trip-1',
      driverId: 'driver-1',
      busNumber: '10',
      routeId: 'route-1',
      direction: 'outbound',
      status: status,
      startedAt: started,
      endedAt: ended,
    );
  }

  test('returns elapsed duration for a completed trip with valid timestamps', () {
    final result = TripDurationCalculator.calculate(
      trip(
        started: startedAt,
        ended: DateTime.utc(2026, 10, 3, 9, 47, 30),
      ),
    );

    expect(result, const Duration(hours: 1, minutes: 32, seconds: 30));
  });

  test('returns zero duration when endedAt equals startedAt', () {
    final result = TripDurationCalculator.calculate(
      trip(
        started: startedAt,
        ended: startedAt,
      ),
    );

    expect(result, Duration.zero);
  });

  test('returns null for an active trip', () {
    final result = TripDurationCalculator.calculate(
      trip(
        status: VehicleTripStatus.active,
        started: startedAt,
        ended: DateTime.utc(2026, 10, 3, 9, 47, 30),
      ),
    );

    expect(result, isNull);
  });

  test('returns null for a cancelled trip', () {
    final result = TripDurationCalculator.calculate(
      trip(
        status: VehicleTripStatus.cancelled,
        started: startedAt,
        ended: DateTime.utc(2026, 10, 3, 9, 47, 30),
      ),
    );

    expect(result, isNull);
  });

  test('returns null when startedAt is missing', () {
    final result = TripDurationCalculator.calculate(
      trip(
        started: null,
        ended: DateTime.utc(2026, 10, 3, 9, 47, 30),
      ),
    );

    expect(result, isNull);
  });

  test('returns null when endedAt is missing', () {
    final result = TripDurationCalculator.calculate(
      trip(
        started: startedAt,
        ended: null,
      ),
    );

    expect(result, isNull);
  });

  test('returns null when endedAt is before startedAt', () {
    final result = TripDurationCalculator.calculate(
      trip(
        started: startedAt,
        ended: startedAt.subtract(const Duration(seconds: 1)),
      ),
    );

    expect(result, isNull);
  });

  test('does not modify the input VehicleTrip', () {
    final originalStartedAt = startedAt;
    final originalEndedAt = DateTime.utc(2026, 10, 3, 9, 47, 30);

    final vehicleTrip = trip(
      started: originalStartedAt,
      ended: originalEndedAt,
    );

    TripDurationCalculator.calculate(vehicleTrip);

    expect(vehicleTrip.status, VehicleTripStatus.completed);
    expect(vehicleTrip.startedAt, originalStartedAt);
    expect(vehicleTrip.endedAt, originalEndedAt);
    expect(vehicleTrip.id, 'trip-1');
    expect(vehicleTrip.driverId, 'driver-1');
    expect(vehicleTrip.busNumber, '10');
    expect(vehicleTrip.routeId, 'route-1');
    expect(vehicleTrip.direction, 'outbound');
  });
}
