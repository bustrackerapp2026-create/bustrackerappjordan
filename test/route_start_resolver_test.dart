import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/planned_route.dart';
import 'package:jordan_bus_tracker_new/models/route_point.dart';
import 'package:jordan_bus_tracker_new/services/route_start_resolver.dart';

void main() {
  RoutePoint point(double latitude, double longitude) =>
      RoutePoint(latitude: latitude, longitude: longitude);

  PlannedRoute route(RouteDirection direction) {
    return PlannedRoute(
      id: 'route-${direction.firestoreValue}',
      createdBy: 'test',
      lineName: 'test-line',
      direction: direction,
      points: [
        point(31.0000, 35.0000),
        point(31.1000, 35.1000),
        point(31.2000, 35.2000),
      ],
      status: PlannedRouteStatus.approved,
    );
  }

  group('RouteStartResolver', () {
    test('uses points.first for outbound', () {
      final start = RouteStartResolver.resolve(route(RouteDirection.outbound));
      expect(start?.latitude, 31.0000);
      expect(start?.longitude, 35.0000);
    });

    test('uses points.first for return', () {
      final start = RouteStartResolver.resolve(route(RouteDirection.returnTrip));
      expect(start?.latitude, 31.0000);
      expect(start?.longitude, 35.0000);
    });

    test('returns null for an empty route', () {
      final r = PlannedRoute(
        id: 'empty',
        createdBy: 'test',
        lineName: 'test-line',
        direction: RouteDirection.returnTrip,
        points: const [],
        status: PlannedRouteStatus.approved,
      );
      expect(RouteStartResolver.resolve(r), isNull);
    });
  });
}
