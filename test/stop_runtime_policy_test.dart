import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';
import 'package:jordan_bus_tracker_new/services/next_stop_resolver.dart';
import 'package:jordan_bus_tracker_new/services/route_plan/route_polyline_projection.dart';
import 'package:jordan_bus_tracker_new/services/stop_runtime_policy.dart';
import 'package:jordan_bus_tracker_new/services/stop_state_resolver.dart';

void main() {
  PlannedRouteStopModel stop() {
    return PlannedRouteStopModel(
      id: 'stop-1',
      name: 'Stop 1',
      location: const GeoPoint(31.0, 35.0),
      order: 0,
    );
  }

  ProjectedPlannedRouteStop projected(double distanceToRouteMeters) {
    return ProjectedPlannedRouteStop(
      stop: stop(),
      projection: RoutePolylineProjection(
        alongMeters: 500,
        distanceToRouteMeters: distanceToRouteMeters,
        segmentIndex: 0,
        segmentT: 0.5,
      ),
    );
  }

  group('StopRuntimePolicy', () {
    test('production policy exposes the approved baseline values', () {
      final policy = StopRuntimePolicy.production();

      expect(
        policy.stopEligibilityDistanceMeters,
        StopRuntimePolicy.productionStopEligibilityDistanceMeters,
      );
      expect(policy.stopEligibilityDistanceMeters, 75);
      expect(policy.statePolicy.atStopRadius, 30);
      expect(policy.statePolicy.approachingDistance, 200);
    });

    test('accepts stops at or inside the production eligibility radius', () {
      final policy = StopRuntimePolicy.production();

      expect(policy.isEligible(projected(0)), isTrue);
      expect(policy.isEligible(projected(75)), isTrue);
    });

    test('rejects stops outside the production eligibility radius', () {
      final policy = StopRuntimePolicy.production();

      expect(policy.isEligible(projected(75.001)), isFalse);
      expect(policy.isEligible(projected(100)), isFalse);
    });

    test('rejects invalid projected route distances', () {
      final policy = StopRuntimePolicy.production();

      expect(policy.isEligible(projected(-1)), isFalse);
      expect(policy.isEligible(projected(double.nan)), isFalse);
      expect(policy.isEligible(projected(double.infinity)), isFalse);
    });

    test('rejects an invalid custom eligibility threshold', () {
      expect(
        () => StopRuntimePolicy(
          stopEligibilityDistanceMeters: 0,
          statePolicy: StopStatePolicy(
            atStopRadius: 30,
            approachingDistance: 200,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('exposes eligibility in the resolver callback shape', () {
      final policy = StopRuntimePolicy.production();

      final PlannedRouteStopEligibility eligibility = policy.eligibility;

      expect(eligibility(projected(75)), isTrue);
      expect(eligibility(projected(76)), isFalse);
    });
  });
}
