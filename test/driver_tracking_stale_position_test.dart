import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jordan_bus_tracker_new/driver/services/driver_tracking_lifecycle.dart';
import 'package:jordan_bus_tracker_new/services/location_service.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  final StreamController<Position> positionController =
      StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() => Future.value(true);

  @override
  Future<LocationPermission> checkPermission() =>
      Future.value(LocationPermission.always);

  @override
  Future<LocationPermission> requestPermission() =>
      Future.value(LocationPermission.always);

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    return positionController.stream;
  }

  void emit(Position position) {
    positionController.add(position);
  }

  void emitError(Object error, [StackTrace? stackTrace]) {
    positionController.addError(error, stackTrace ?? StackTrace.current);
  }

  Future<void> dispose() => positionController.close();
}

Position _positionAt(DateTime timestamp) {
  return Position(
    longitude: 35.9106,
    latitude: 31.9539,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 750,
    altitudeAccuracy: 1,
    heading: 90,
    headingAccuracy: 1,
    speed: 8,
    speedAccuracy: 1,
    isMocked: false,
  );
}

void main() {
  test(
    'does not replay a stale cached position as a live driver event after stream error',
    () async {
      final previousPlatform = GeolocatorPlatform.instance;
      final fakePlatform = _FakeGeolocatorPlatform();
      final locationService = LocationService();
      final lifecycle = DriverTrackingLifecycle(
        locationService: locationService,
      );
      final received = <Position>[];

      locationService.clearLastKnownPosition();
      GeolocatorPlatform.instance = fakePlatform;

      StreamSubscription<Position>? primingSubscription;

      try {
        // Prime LocationService with a stale cached fix without involving the lifecycle.
        primingSubscription = locationService
            .getPositionStreamForProfile(LocationTrackingProfile.driverTrip)
            .listen((_) {});

        final stalePosition = _positionAt(
          DateTime.now().subtract(const Duration(seconds: 60)),
        );
        fakePlatform.emit(stalePosition);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await primingSubscription.cancel();
        primingSubscription = null;

        lifecycle.onPosition = received.add;

        await lifecycle.requestStart(
          uid: 'test-driver',
          profile: LocationTrackingProfile.driverTrip,
        );

        final baselineLastPositionAt = lifecycle.lastPositionAt;

        fakePlatform.emitError(StateError('simulated GPS stream failure'));

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(received, isEmpty);
        expect(lifecycle.lastPosition, isNull);
        expect(lifecycle.lastPositionAt, equals(baselineLastPositionAt));
      } finally {
        await primingSubscription?.cancel();
        await lifecycle.dispose();
        locationService.clearLastKnownPosition();
        GeolocatorPlatform.instance = previousPlatform;
        await fakePlatform.dispose();
      }
    },
  );
}
