import 'package:flutter_test/flutter_test.dart';
import 'package:jordan_bus_tracker_new/core/trip/trip_acceptance.dart';
import 'package:jordan_bus_tracker_new/services/trip_service_exception.dart';

void main() {
  group('TripAcceptance.evaluatePassengerCancel', () {
    test('يلغي طلب pending لنفس الراكب', () {
      final decision = TripAcceptance.evaluatePassengerCancel(
        exists: true,
        tripPassengerId: 'p1',
        actingPassengerId: 'p1',
        currentStatus: 'pending',
      );
      expect(decision, PassengerCancelDecision.applyCancel);
    });

    test('يلغي رحلة active لنفس الراكب', () {
      final decision = TripAcceptance.evaluatePassengerCancel(
        exists: true,
        tripPassengerId: 'p1',
        actingPassengerId: 'p1',
        currentStatus: 'active',
      );
      expect(decision, PassengerCancelDecision.applyCancel);
    });

    test('رحلة مكتملة أو ملغاة مسبقاً → alreadyTerminal بدون خطأ', () {
      expect(
        TripAcceptance.evaluatePassengerCancel(
          exists: true,
          tripPassengerId: 'p1',
          actingPassengerId: 'p1',
          currentStatus: 'completed',
        ),
        PassengerCancelDecision.alreadyTerminal,
      );
      expect(
        TripAcceptance.evaluatePassengerCancel(
          exists: true,
          tripPassengerId: 'p1',
          actingPassengerId: 'p1',
          currentStatus: 'cancelled',
        ),
        PassengerCancelDecision.alreadyTerminal,
      );
    });

    test('يرفض إلغاء راكب آخر', () {
      expect(
        () => TripAcceptance.evaluatePassengerCancel(
          exists: true,
          tripPassengerId: 'p1',
          actingPassengerId: 'p2',
          currentStatus: 'pending',
        ),
        throwsA(
          isA<TripServiceException>().having(
            (e) => e.message,
            'message',
            contains('غير مصرح'),
          ),
        ),
      );
    });

    test('يرفض عند عدم وجود الرحلة', () {
      expect(
        () => TripAcceptance.evaluatePassengerCancel(
          exists: false,
          tripPassengerId: null,
          actingPassengerId: 'p1',
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
  });

  group('TripAcceptance.ensureDriverCanReject', () {
    test('يرفض pending للسائق المعيّن', () {
      expect(
        () => TripAcceptance.ensureDriverCanReject(
          exists: true,
          currentStatus: 'pending',
          assignedDriverId: 'd1',
          actingDriverId: 'd1',
        ),
        returnsNormally,
      );
    });

    test('يرفض active للسائق المعيّن', () {
      expect(
        () => TripAcceptance.ensureDriverCanReject(
          exists: true,
          currentStatus: 'active',
          assignedDriverId: 'd1',
          actingDriverId: 'd1',
        ),
        returnsNormally,
      );
    });

    test('يمنع سائقاً غير معيّن', () {
      expect(
        () => TripAcceptance.ensureDriverCanReject(
          exists: true,
          currentStatus: 'pending',
          assignedDriverId: 'd1',
          actingDriverId: 'd2',
        ),
        throwsA(isA<TripServiceException>()),
      );
    });

    test('يمنع رفض رحلة مكتملة', () {
      expect(
        () => TripAcceptance.ensureDriverCanReject(
          exists: true,
          currentStatus: 'completed',
          assignedDriverId: 'd1',
          actingDriverId: 'd1',
        ),
        throwsA(isA<TripServiceException>()),
      );
    });
  });

  group('سيناريو: طلب → قبول → إلغاء راكب', () {
    test('مسار الحالات صالح', () {
      // pending قابل للقبول
      TripAcceptance.ensureCanAccept(
        exists: true,
        currentStatus: 'pending',
      );
      TripAcceptance.ensureAssignedDriver(
        assignedDriverId: 'd1',
        actingDriverId: 'd1',
      );

      // بعد القبول: active — الراكب ما زال يلغي
      final cancelAfterAccept = TripAcceptance.evaluatePassengerCancel(
        exists: true,
        tripPassengerId: 'p1',
        actingPassengerId: 'p1',
        currentStatus: 'active',
      );
      expect(cancelAfterAccept, PassengerCancelDecision.applyCancel);

      // بعد الإلغاء: لا قبول جديد
      expect(
        () => TripAcceptance.ensureCanAccept(
          exists: true,
          currentStatus: 'cancelled',
        ),
        throwsA(isA<TripServiceException>()),
      );
    });
  });
}
