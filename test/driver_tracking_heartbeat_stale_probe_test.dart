import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jordan_bus_tracker_new/driver/services/driver_tracking_lifecycle.dart';
import 'package:jordan_bus_tracker_new/services/location_service.dart';

class _HeartbeatFakeGeolocatorPlatform extends GeolocatorPlatform {
  _HeartbeatFakeGeolocatorPlatform(this.currentPosition);

  final Position currentPosition;
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
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) {
    return Future.value(null);
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) {
    return Future.value(currentPosition);
  }

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    return positionController.stream;
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
    'heartbeat does not refresh lastPositionAt from a stale current-position probe',
    () async {
      final previousPlatform = GeolocatorPlatform.instance;
      final stalePosition = _positionAt(
        DateTime.now().subtract(const Duration(seconds: 60)),
      );
      final fakePlatform =
          _HeartbeatFakeGeolocatorPlatform(stalePosition);
      final locationService = LocationService();
      final lifecycle = DriverTrackingLifecycle(
        locationService: locationService,
      );
      final received = <Position>[];

      locationService.clearLastKnownPosition();
      GeolocatorPlatform.instance = fakePlatform;
      lifecycle.onPosition = received.add;

      try {
        await lifecycle.requestStart(
          uid: 'test-driver',
          profile: LocationTrackingProfile.driverTrip,
        );

        lifecycle.lastPositionAt =
            DateTime.now().subtract(const Duration(seconds: 46));
        final baselineLastPositionAt = lifecycle.lastPositionAt;

        await Future<void>.delayed(const Duration(seconds: 16));

        expect(received, isEmpty);
        expect(lifecycle.lastPosition, isNull);
        expect(lifecycle.lastPositionAt, equals(baselineLastPositionAt));
      } finally {
        await lifecycle.dispose();
        locationService.clearLastKnownPosition();
        GeolocatorPlatform.instance = previousPlatform;
        await fakePlatform.dispose();
      }
    },
  );
}
