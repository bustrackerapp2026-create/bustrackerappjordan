import 'package:flutter_test/flutter_test.dart';
import 'package:bustrackerappjordan/models/pickup_point_model.dart';

void main() {
  group('PickupPointModel', () {
    test('uses bus as default point type when omitted', () {
      final model = PickupPointModel(
        id: '1',
        name: 'موقف الشمال',
        latitude: 31.95,
        longitude: 35.93,
        addedBy: 'user-1',
      );

      expect(model.pointType, 'bus');
    });

    test('preserves point type from Firestore map', () {
      final model = PickupPointModel.fromMap(
        {
          'name': 'موقف الركاب',
          'latitude': 31.95,
          'longitude': 35.93,
          'addedBy': 'user-1',
          'pointType': 'passenger',
        },
        'doc-1',
      );

      expect(model.pointType, 'passenger');
      expect(model.toMap()['pointType'], 'passenger');
    });
  });
}
