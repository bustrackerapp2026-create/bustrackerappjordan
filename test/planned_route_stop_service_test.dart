import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/services/planned_route_stop_service.dart';

void main() {
  group('PlannedRouteStopService', () {
    test('returns an empty stream for an empty route id', () async {
      final service = PlannedRouteStopService();

      expect(
        await service.watchStops('   ').first,
        isEmpty,
      );
    });

    test('returns an empty list for an empty route id', () async {
      final service = PlannedRouteStopService();

      expect(
        await service.fetchStops('   '),
        isEmpty,
      );
    });

  });
}
