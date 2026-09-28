import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/route_progress_tracker.dart';

void main() {
  RoutePoint point(double latitude, double longitude) =>
      RoutePoint(latitude: latitude, longitude: longitude);

  final straightRoute = [
    point(31.0000, 35.0000),
    point(31.0000, 35.0100),
    point(31.0000, 35.0200),
  ];

  group('RouteProgressTracker', () {
    test('accepts the first valid projection', () {
      final tracker = RouteProgressTracker();

      final result = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
      );

      expect(result, isNotNull);
      expect(result!.progress, closeTo(0.0, 0.0005));
      expect(tracker.lastAccepted, same(result));
    });

    test('keeps progress monotonic when GPS jitters backwards', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0100,
      );
      final jitter = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0098,
      );

      expect(first, isNotNull);
      expect(jitter, isNotNull);
      expect(jitter!.progress, closeTo(first!.progress, 0.0001));
      expect(jitter.alongMeters, closeTo(first.alongMeters, 0.1));
      expect(jitter.distanceToRouteMeters, closeTo(0.0, 0.1));
    });

    test('accepts later forward progress after backward jitter', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0100,
      );
      final later = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0120,
      );

      expect(first, isNotNull);
      expect(later, isNotNull);
      expect(later!.progress, greaterThan(first!.progress));
      expect(later.alongMeters, greaterThan(first.alongMeters));
    });

    test('rejects an implausibly large forward jump by retaining state', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
      );
      final jump = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0040,
      );

      expect(first, isNotNull);
      expect(jump, isNotNull);
      expect(jump!.progress, closeTo(first!.progress, 0.0001));
      expect(jump.alongMeters, closeTo(first.alongMeters, 0.1));
      expect(tracker.lastAccepted!.progress, closeTo(first.progress, 0.0001));
    });

    test('ignores invalid or off-route samples without changing state', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0050,
      );
      final invalid = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0100,
        longitude: 35.0050,
      );

      expect(first, isNotNull);
      expect(invalid, isNull);
      expect(tracker.lastAccepted, same(first));
    });

    test('seedFromProgress prevents the next sample from moving backwards',
        () {
      final tracker = RouteProgressTracker();

      final seeded = tracker.seedFromProgress(
        routePoints: straightRoute,
        progress: 0.5,
      );
      final behind = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0040,
      );

      expect(seeded, isTrue);
      expect(behind, isNotNull);
      expect(behind!.progress, closeTo(0.5, 0.001));
    });

    test('seedFromProgress rejects invalid progress values', () {
      final tracker = RouteProgressTracker();

      expect(
        tracker.seedFromProgress(
          routePoints: straightRoute,
          progress: double.nan,
        ),
        isFalse,
      );
      expect(
        tracker.seedFromProgress(
          routePoints: straightRoute,
          progress: 1.1,
        ),
        isFalse,
      );
      expect(tracker.lastAccepted, isNull);
    });

    test('reset clears continuity state for a new VehicleTrip', () {
      final tracker = RouteProgressTracker();

      tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0100,
      );

      tracker.reset();

      expect(tracker.lastAccepted, isNull);

      final newTripStart = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
      );

      expect(newTripStart, isNotNull);
      expect(newTripStart!.progress, closeTo(0.0, 0.0005));
    });
  });
}
