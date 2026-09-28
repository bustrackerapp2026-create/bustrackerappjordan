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

  final t0 = DateTime.utc(2026, 1, 1);

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

    test('seeds from persisted progress and clears physical metadata', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 20.0,
      );
      expect(first, isNotNull);

      expect(
        tracker.seedFromProgress(
          routePoints: straightRoute,
          progress: 0.5,
        ),
        isTrue,
      );

      final forward = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0125,
        timestamp: t0.add(const Duration(seconds: 1)),
        speedMetersPerSecond: 20.0,
      );

      expect(forward, isNotNull);
      expect(forward!.progress, greaterThan(0.5));
    });

    test('rejects a forward move above the physical allowance', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 0.0,
      );
      final constrained = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0003,
        timestamp: t0.add(const Duration(seconds: 5)),
        speedMetersPerSecond: 0.0,
      );

      expect(first, isNotNull);
      expect(constrained, same(first));
      expect(tracker.lastAccepted, same(first));
    });

    test('accepts forward movement within the physical allowance', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 0.0,
      );
      final constrained = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0002,
        timestamp: t0.add(const Duration(seconds: 5)),
        speedMetersPerSecond: 0.0,
      );

      expect(first, isNotNull);
      expect(constrained, isNotNull);
      expect(constrained!.progress, greaterThan(first!.progress));
    });

    test('uses current valid speed before the previous valid speed', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 0.0,
      );
      final later = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0010,
        timestamp: t0.add(const Duration(seconds: 5)),
        speedMetersPerSecond: 20.0,
      );

      expect(first, isNotNull);
      expect(later, isNotNull);
      expect(later!.progress, greaterThan(first!.progress));
    });

    test('falls back to the previous accepted valid speed', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 10.0,
      );
      final later = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0015,
        timestamp: t0.add(const Duration(seconds: 5)),
        speedMetersPerSecond: -1.0,
      );

      expect(first, isNotNull);
      expect(later, isNull);
      expect(tracker.lastAccepted, same(first));
    });

    test('same timestamp blocks positive forward movement', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 10.0,
      );
      final sameTimestamp = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0005,
        timestamp: t0,
        speedMetersPerSecond: 10.0,
      );

      expect(first, isNotNull);
      expect(sameTimestamp, same(first));
    });

    test('long timestamp gaps remain governed by the existing 300 m guard', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 0.0,
      );
      final longGap = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0020,
        timestamp: t0.add(const Duration(seconds: 31)),
        speedMetersPerSecond: 0.0,
      );

      expect(first, isNotNull);
      expect(longGap, isNotNull);
      expect(longGap!.progress, greaterThan(first!.progress));
    });

    test('a backward accepted sample becomes the new physical reference', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0050,
        timestamp: t0,
        speedMetersPerSecond: 20.0,
      );
      final backward = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0045,
        timestamp: t0.add(const Duration(seconds: 5)),
        speedMetersPerSecond: 0.0,
      );
      final forward = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0053,
        timestamp: t0.add(const Duration(seconds: 10)),
        speedMetersPerSecond: 0.0,
      );

      expect(first, isNotNull);
      expect(backward, isNotNull);
      expect(backward!.progress, closeTo(first!.progress, 0.001));
      expect(forward, same(backward));
    });

    test('a rejected sample does not advance the physical reference state', () {
      final tracker = RouteProgressTracker();

      final first = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0,
        speedMetersPerSecond: 0.0,
      );
      final rejected = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0003,
        timestamp: t0.add(const Duration(seconds: 5)),
        speedMetersPerSecond: 20.0,
      );
      final afterRejected = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0003,
        timestamp: t0.add(const Duration(seconds: 6)),
        speedMetersPerSecond: -1.0,
      );

      expect(first, isNotNull);
      expect(rejected, same(first));
      expect(afterRejected, same(first));
      expect(tracker.lastAccepted, same(first));
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
        timestamp: t0,
        speedMetersPerSecond: 10.0,
      );

      tracker.reset();

      expect(tracker.lastAccepted, isNull);

      final newTripStart = tracker.update(
        routePoints: straightRoute,
        latitude: 31.0000,
        longitude: 35.0000,
        timestamp: t0.add(const Duration(seconds: 5)),
        speedMetersPerSecond: 0.0,
      );

      expect(newTripStart, isNotNull);
      expect(newTripStart!.progress, closeTo(0.0, 0.0005));
    });
  });
}
