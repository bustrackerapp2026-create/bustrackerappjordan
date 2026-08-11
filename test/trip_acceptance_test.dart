import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/core/trip/trip_acceptance.dart';
import 'package:jordan_bus_tracker_new/models/trip_status.dart';
import 'package:jordan_bus_tracker_new/services/trip_service_exception.dart';

void main() {
  group('TripAcceptance.canAccept', () {
    test('allows only pending trips', () {
      expect(TripAcceptance.canAccept(currentStatus: 'pending'), isTrue);
      expect(TripAcceptance.canAccept(currentStatus: 'active'), isFalse);
      expect(TripAcceptance.canAccept(currentStatus: 'completed'), isFalse);
      expect(TripAcceptance.canAccept(currentStatus: 'cancelled'), isFalse);
      expect(TripAcceptance.canAccept(currentStatus: null), isFalse);
    });
  });

  group('TripAcceptance.ensureCanAccept (محاكاة قبول الرحلة)', () {
    test('ينجح عندما تكون الرحلة موجودة وحالتها pending', () {
      expect(
        () => TripAcceptance.ensureCanAccept(
          exists: true,
          currentStatus: 'pending',
        ),
        returnsNormally,
      );
    });

    test('يرفض عندما الرحلة غير موجودة', () {
      expect(
        () => TripAcceptance.ensureCanAccept(
          exists: false,
          currentStatus: null,
        ),
        throwsA(
          isA<TripServiceException>().having(
            (e) => e.message,
            'message',
            contains('غير موجودة'),
          ),
        ),
      );
    });

    test('يرفض عندما قبلها سائق آخر (active)', () {
      expect(
        () => TripAcceptance.ensureCanAccept(
          exists: true,
          currentStatus: 'active',
        ),
        throwsA(
          isA<TripServiceException>().having(
            (e) => e.message,
            'message',
            contains('سائق آخر'),
          ),
        ),
      );
    });

    test('يرفض الرحلات المكتملة أو الملغاة', () {
      for (final status in ['completed', 'cancelled']) {
        expect(
          () => TripAcceptance.ensureCanAccept(
            exists: true,
            currentStatus: status,
          ),
          throwsA(isA<TripServiceException>()),
          reason: 'status=$status',
        );
      }
    });
  });

  group('TripAcceptance.acceptanceUpdateFields', () {
    test('يضع الحالة active ومعرف السائق', () {
      final fields = TripAcceptance.acceptanceUpdateFields('driver-42');

      expect(fields['status'], 'active');
      expect(fields['driverId'], 'driver-42');
    });
  });

  group('TripAcceptance.ensureValidStatusTransition', () {
    test('pending → active و cancelled مسموح', () {
      expect(
        () => TripAcceptance.ensureValidStatusTransition(
          TripStatus.pending,
          TripStatus.active,
        ),
        returnsNormally,
      );
      expect(
        () => TripAcceptance.ensureValidStatusTransition(
          TripStatus.pending,
          TripStatus.cancelled,
        ),
        returnsNormally,
      );
    });

    test('pending → completed مرفوض', () {
      expect(
        () => TripAcceptance.ensureValidStatusTransition(
          TripStatus.pending,
          TripStatus.completed,
        ),
        throwsA(isA<TripServiceException>()),
      );
    });

    test('active → completed و cancelled مسموح', () {
      expect(
        () => TripAcceptance.ensureValidStatusTransition(
          TripStatus.active,
          TripStatus.completed,
        ),
        returnsNormally,
      );
      expect(
        () => TripAcceptance.ensureValidStatusTransition(
          TripStatus.active,
          TripStatus.cancelled,
        ),
        returnsNormally,
      );
    });

    test('completed و cancelled نهائيتان', () {
      expect(
        () => TripAcceptance.ensureValidStatusTransition(
          TripStatus.completed,
          TripStatus.active,
        ),
        throwsA(isA<TripServiceException>()),
      );
      expect(
        () => TripAcceptance.ensureValidStatusTransition(
          TripStatus.cancelled,
          TripStatus.pending,
        ),
        throwsA(isA<TripServiceException>()),
      );
    });
  });

  group('سيناريو محاكاة سائقين يتنافسان على نفس الطلب', () {
    test('الأول يقبل، والثاني يُرفض', () {
      // محاكاة: الرحلة ما زالت معلّقة → السائق الأول ينجح
      TripAcceptance.ensureCanAccept(
        exists: true,
        currentStatus: 'pending',
      );
      final afterFirst = TripAcceptance.acceptanceUpdateFields('driver-A');
      expect(afterFirst['status'], 'active');
      expect(afterFirst['driverId'], 'driver-A');

      // محاكاة: بعد قبول الأول أصبحت active → السائق الثاني يفشل
      expect(
        () => TripAcceptance.ensureCanAccept(
          exists: true,
          currentStatus: afterFirst['status'] as String,
        ),
        throwsA(isA<TripServiceException>()),
      );
    });
  });
}
