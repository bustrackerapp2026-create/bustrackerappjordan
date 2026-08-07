import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/models/pickup_point_model.dart';

void main() {
  group('PickupPointModel review notes', () {
    test('parses and preserves review notes from Firestore data', () {
      final model = PickupPointModel.fromMap({
        'name': 'مثال نقطة',
        'latitude': 31.95,
        'longitude': 35.91,
        'addedBy': 'user-1',
        'status': 'pending',
        'pointType': 'bus',
        'reviewNote': 'أرغب بتعديل الموقع',
      }, 'point-1');

      expect(model.reviewNote, 'أرغب بتعديل الموقع');

      final updated = model.copyWith(reviewNote: 'تم تعديل الاسم');
      expect(updated.reviewNote, 'تم تعديل الاسم');
    });
  });
}
