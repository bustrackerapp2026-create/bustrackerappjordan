import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/models/trip_model.dart';
import 'package:jordan_bus_tracker_new/models/trip_status.dart';

void main() {
  final createdAt = DateTime(2026, 1, 15, 10, 30);

  TripModel buildTrip({
    TripStatus status = TripStatus.pending,
    List<RoutePoint>? routePoints,
    String pickup = 'وسط البلد',
    String dropoff = 'جامعة الأردن',
  }) {
    return TripModel(
      id: 'trip-1',
      passengerId: 'p1',
      driverId: 'd1',
      pickupPoint: pickup,
      dropoffPoint: dropoff,
      createdAt: createdAt,
      status: status,
      routePoints: routePoints,
    );
  }

  group('TripModel construction', () {
    test('creates pending trip with defaults', () {
      final trip = buildTrip();

      expect(trip.id, 'trip-1');
      expect(trip.status, TripStatus.pending);
      expect(trip.pickupPoint, 'وسط البلد');
      expect(trip.dropoffPoint, 'جامعة الأردن');
      expect(trip.routePoints, isNull);
    });

    test('throws when pickup exceeds max length', () {
      expect(
        () => buildTrip(pickup: 'x' * 101),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when notes exceed max length', () {
      expect(
        () => TripModel(
          id: 't',
          passengerId: 'p',
          driverId: 'd',
          pickupPoint: 'A',
          dropoffPoint: 'B',
          createdAt: createdAt,
          notes: 'n' * 501,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('completed trip may omit route points (current model)', () {
      // النموذج الحالي لا يفرض routePoints عند completed
      // حتى لا يكسر إكمال الرحلة من الواجهة بدون مسار مسجّل.
      expect(
        () => buildTrip(status: TripStatus.completed),
        returnsNormally,
      );

      final withPoints = buildTrip(
        status: TripStatus.completed,
        routePoints: [
          RoutePoint(latitude: 31.95, longitude: 35.91, timestamp: createdAt),
        ],
      );
      expect(withPoints.routePoints, isNotNull);
      expect(withPoints.routePoints!.length, 1);
      expect(withPoints.status, TripStatus.completed);
    });
  });

  group('TripModel.fromMap', () {
    test('parses status and basic fields from map', () {
      final trip = TripModel.fromMap({
        'passengerId': 'p9',
        'driverId': 'd9',
        'pickupPoint': 'النصر',
        'dropoffPoint': 'العبدلي',
        'createdAt': createdAt,
        'status': 'active',
        'fare': 1.25,
        'notes': 'ملاحظة',
      }, 'doc-9');

      expect(trip.id, 'doc-9');
      expect(trip.passengerId, 'p9');
      expect(trip.driverId, 'd9');
      expect(trip.status, TripStatus.active);
      expect(trip.fare, 1.25);
      expect(trip.notes, 'ملاحظة');
      expect(trip.createdAt, createdAt);
    });

    test('unknown status becomes pending', () {
      final trip = TripModel.fromMap({
        'passengerId': 'p',
        'driverId': 'd',
        'pickupPoint': 'A',
        'dropoffPoint': 'B',
        'createdAt': createdAt,
        'status': 'weird',
      }, 'doc-x');

      expect(trip.status, TripStatus.pending);
    });
  });

  group('TripModel.copyWith', () {
    test('updates status while keeping other fields', () {
      final original = buildTrip();
      final updated = original.copyWith(status: TripStatus.active);

      expect(updated.status, TripStatus.active);
      expect(updated.pickupPoint, original.pickupPoint);
      expect(updated.driverId, original.driverId);
    });
  });
}
