import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/vehicle_trip.dart';
import 'package:jordan_bus_tracker_new/services/vehicle_trip_service.dart';

void main() {
  VehicleTrip trip({
    required String id,
    String routeId = 'route-1',
    String direction = 'outbound',
    VehicleTripStatus status = VehicleTripStatus.active,
  }) {
    return VehicleTrip(
      id: id,
      driverId: 'driver-$id',
      busNumber: 'bus-$id',
      routeId: routeId,
      direction: direction,
      status: status,
    );
  }

  test('reads active trips using normalized routeId and direction', () async {
    String? capturedRouteId;
    String? capturedDirection;

    final service = VehicleTripService.forTesting(
      activeTripsForRouteReader: ({
        required routeId,
        required direction,
      }) async {
        capturedRouteId = routeId;
        capturedDirection = direction;
        return [trip(id: 'trip-1')];
      },
    );

    final result = await service.findActiveTripsForRoute(
      routeId: '  route-1  ',
      direction: ' OUTBOUND ',
    );

    expect(capturedRouteId, 'route-1');
    expect(capturedDirection, 'outbound');
    expect(result.map((t) => t.id), ['trip-1']);
  });

  test('returns an empty list when no active records are found', () async {
    final service = VehicleTripService.forTesting(
      activeTripsForRouteReader: ({
        required routeId,
        required direction,
      }) async =>
          const <VehicleTrip>[],
    );

    final result = await service.findActiveTripsForRoute(
      routeId: 'route-1',
      direction: 'outbound',
    );

    expect(result, isEmpty);
  });

  test('rejects an empty routeId before reading', () async {
    var readerCalled = false;

    final service = VehicleTripService.forTesting(
      activeTripsForRouteReader: ({
        required routeId,
        required direction,
      }) async {
        readerCalled = true;
        return [trip(id: 'trip-1')];
      },
    );

    expect(
      () => service.findActiveTripsForRoute(
        routeId: '   ',
        direction: 'outbound',
      ),
      throwsA(
        isA<VehicleTripServiceException>().having(
          (e) => e.code,
          'code',
          'invalid-route-id',
        ),
      ),
    );
    expect(readerCalled, isFalse);
  });

  test('rejects an invalid direction before reading', () async {
    var readerCalled = false;

    final service = VehicleTripService.forTesting(
      activeTripsForRouteReader: ({
        required routeId,
        required direction,
      }) async {
        readerCalled = true;
        return [trip(id: 'trip-1')];
      },
    );

    expect(
      () => service.findActiveTripsForRoute(
        routeId: 'route-1',
        direction: 'sideways',
      ),
      throwsA(
        isA<VehicleTripServiceException>().having(
          (e) => e.code,
          'code',
          'invalid-direction',
        ),
      ),
    );
    expect(readerCalled, isFalse);
  });

  test(
    'filters records whose persisted route identity is inconsistent',
    () async {
      final service = VehicleTripService.forTesting(
        activeTripsForRouteReader: ({
          required routeId,
          required direction,
        }) async =>
            [
              trip(id: 'valid'),
              trip(id: 'wrong-route', routeId: 'route-2'),
              trip(id: 'wrong-direction', direction: 'return'),
            ],
      );

      final result = await service.findActiveTripsForRoute(
        routeId: 'route-1',
        direction: 'outbound',
      );

      expect(result.map((t) => t.id), ['valid']);
    },
  );

  test('filters records that are no longer active', () async {
    final service = VehicleTripService.forTesting(
      activeTripsForRouteReader: ({
        required routeId,
        required direction,
      }) async =>
          [
            trip(id: 'active'),
            trip(
              id: 'completed',
              status: VehicleTripStatus.completed,
            ),
            trip(
              id: 'cancelled',
              status: VehicleTripStatus.cancelled,
            ),
          ],
    );

    final result = await service.findActiveTripsForRoute(
      routeId: 'route-1',
      direction: 'outbound',
    );

    expect(result.map((t) => t.id), ['active']);
  });

  test(
    'does not filter an active trip only because currentLocation is absent',
    () async {
      final service = VehicleTripService.forTesting(
        activeTripsForRouteReader: ({
          required routeId,
          required direction,
        }) async =>
            [trip(id: 'no-location')],
      );

      final result = await service.findActiveTripsForRoute(
        routeId: 'route-1',
        direction: 'outbound',
      );

      expect(result, hasLength(1));
      expect(result.single.currentLocation, isNull);
    },
  );
}
