import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:jordan_bus_tracker_new/services/vehicle_trip_service.dart';

void main() {
  const location = GeoPoint(31.0, 35.0);

  group('VehicleTrip live location routeProgress persistence', () {
    test('includes valid routeProgress in the live update payload', () {
      final payload = VehicleTripService.buildLiveLocationUpdatePayload(
        currentLocation: location,
        speed: 10.0,
        heading: 90.0,
        routeProgress: 0.5,
      );

      expect(payload['currentLocation'], location);
      expect(payload['speed'], 10.0);
      expect(payload['heading'], 90.0);
      expect(payload['routeProgress'], closeTo(0.5, 0.0001));
    });

    test('omits routeProgress when it is null', () {
      final payload = VehicleTripService.buildLiveLocationUpdatePayload(
        currentLocation: location,
        speed: 10.0,
        heading: 90.0,
        routeProgress: null,
      );

      expect(payload.containsKey('routeProgress'), isFalse);
    });

    test('accepts boundary routeProgress values 0 and 1', () {
      final atStart = VehicleTripService.buildLiveLocationUpdatePayload(
        currentLocation: location,
        routeProgress: 0.0,
      );
      final atEnd = VehicleTripService.buildLiveLocationUpdatePayload(
        currentLocation: location,
        routeProgress: 1.0,
      );

      expect(atStart['routeProgress'], 0.0);
      expect(atEnd['routeProgress'], 1.0);
    });

    test('rejects routeProgress below 0', () {
      expect(
        () => VehicleTripService.buildLiveLocationUpdatePayload(
          currentLocation: location,
          routeProgress: -0.1,
        ),
        throwsA(
          isA<VehicleTripServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-route-progress',
          ),
        ),
      );
    });

    test('rejects routeProgress above 1', () {
      expect(
        () => VehicleTripService.buildLiveLocationUpdatePayload(
          currentLocation: location,
          routeProgress: 1.1,
        ),
        throwsA(
          isA<VehicleTripServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-route-progress',
          ),
        ),
      );
    });

    test('rejects non-finite routeProgress', () {
      expect(
        () => VehicleTripService.buildLiveLocationUpdatePayload(
          currentLocation: location,
          routeProgress: double.nan,
        ),
        throwsA(isA<VehicleTripServiceException>()),
      );
      expect(
        () => VehicleTripService.buildLiveLocationUpdatePayload(
          currentLocation: location,
          routeProgress: double.infinity,
        ),
        throwsA(isA<VehicleTripServiceException>()),
      );
    });
  });
}
