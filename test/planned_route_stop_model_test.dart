import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/planned_route_stop_model.dart';

void main() {
  group('PlannedRouteStopModel', () {
    const location = GeoPoint(31.95, 35.91);

    test('stores the modern stop contract without duplicated route fields', () {
      final stop = PlannedRouteStopModel(
        id: 'stop-1',
        name: 'محطة البلد',
        location: location,
        order: 0,
      );

      final map = stop.toMap();

      expect(stop.id, 'stop-1');
      expect(stop.name, 'محطة البلد');
      expect(stop.location, location);
      expect(stop.order, 0);
      expect(stop.isMajor, false);
      expect(map, containsPair('name', 'محطة البلد'));
      expect(map, containsPair('location', location));
      expect(map, containsPair('order', 0));
      expect(map, isNot(contains('routeId')));
      expect(map, isNot(contains('direction')));
      expect(map, isNot(contains('stopAlongMeters')));
      expect(map, isNot(contains('nextStopId')));
      expect(map, isNot(contains('distanceAhead')));
      expect(map, isNot(contains('eta')));
      expect(map, isNot(contains('status')));
      expect(map, isNot(contains('isMajor')));
    });

    test('defaults missing isMajor to false when reading data', () {
      final stop = PlannedRouteStopModel.fromMap('stop-2', {
        'name': 'محطة الجامعة',
        'location': location,
        'order': 3,
      });

      expect(stop.isMajor, false);
      expect(stop.order, 3);
    });

    test('reads an explicit major-stop flag', () {
      final stop = PlannedRouteStopModel.fromMap('stop-3', {
        'name': 'مجمع رئيسي',
        'location': location,
        'order': 4,
        'isMajor': true,
      });

      expect(stop.isMajor, true);
    });

    test('rejects a negative order', () {
      expect(
        () => PlannedRouteStopModel(
          id: 'stop-4',
          name: 'محطة',
          location: location,
          order: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-GeoPoint location when reading data', () {
      expect(
        () => PlannedRouteStopModel.fromMap('stop-5', {
          'name': 'محطة',
          'location': const {'lat': 31.95, 'lng': 35.91},
          'order': 1,
        }),
        throwsFormatException,
      );
    });
  });
}
