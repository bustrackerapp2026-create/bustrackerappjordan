import '../../models/trip_status.dart';
import '../../services/trip_service_exception.dart';

/// نتيجة تقييم إلغاء الراكب (بدون Firebase).
enum PassengerCancelDecision {
  /// نفّذ التحديث إلى cancelled
  applyCancel,

  /// الرحلة منتهية مسبقاً — لا خطأ ولا تحديث
  alreadyTerminal,
}

/// قواعد قبول/إلغاء/رفض الرحلة — منطق نقي قابل للاختبار بدون Firebase.
class TripAcceptance {
  const TripAcceptance._();

  /// هل يمكن قبول الرحلة بحالتها الحالية؟
  static bool canAccept({required String? currentStatus}) {
    return currentStatus == TripStatus.pending.stringValue;
  }

  /// يتحقق قبل قبول الرحلة.
  /// يرمي [TripServiceException] إذا الرحلة غير موجودة أو ليست معلّقة.
  static void ensureCanAccept({
    required bool exists,
    required String? currentStatus,
  }) {
    if (!exists) {
      throw const TripServiceException('الرحلة المطلوبة غير موجودة.');
    }

    if (!canAccept(currentStatus: currentStatus)) {
      throw const TripServiceException(
        'عذراً، تم تغيير حالة هذه الرحلة أو قبولها من قِبل سائق آخر.',
      );
    }
  }

  /// الطلب يجب أن يكون موجّهاً لنفس السائق الذي يحاول القبول.
  static void ensureAssignedDriver({
    required String? assignedDriverId,
    required String actingDriverId,
  }) {
    if (actingDriverId.isEmpty) {
      throw const TripServiceException('معرف السائق مطلوب.');
    }
    if (assignedDriverId == null || assignedDriverId.isEmpty) {
      throw const TripServiceException('الطلب غير مخصّص لسائق.');
    }
    if (assignedDriverId != actingDriverId) {
      throw const TripServiceException('هذا الطلب موجّه لسائق آخر.');
    }
  }

  /// قواعد إلغاء الراكب — نفس شروط [TripService.cancelTripByPassenger].
  static PassengerCancelDecision evaluatePassengerCancel({
    required bool exists,
    required String? tripPassengerId,
    required String actingPassengerId,
    required String? currentStatus,
  }) {
    if (!exists) {
      throw const TripServiceException('الرحلة غير موجودة.');
    }
    if (actingPassengerId.isEmpty) {
      throw const TripServiceException('بيانات الإلغاء غير مكتملة.');
    }
    if (tripPassengerId != actingPassengerId) {
      throw const TripServiceException('غير مصرح بإلغاء هذه الرحلة.');
    }

    final status = currentStatus ?? TripStatus.pending.stringValue;

    if (status == TripStatus.completed.stringValue ||
        status == TripStatus.cancelled.stringValue) {
      return PassengerCancelDecision.alreadyTerminal;
    }

    if (status != TripStatus.pending.stringValue &&
        status != TripStatus.active.stringValue) {
      throw const TripServiceException(
        'لا يمكن إلغاء هذه الرحلة بحالتها الحالية.',
      );
    }

    return PassengerCancelDecision.applyCancel;
  }

  /// رفض السائق للطلب: يجب أن يكون معيّناً والحالة تسمح بالانتقال إلى cancelled.
  static void ensureDriverCanReject({
    required bool exists,
    required String? currentStatus,
    required String? assignedDriverId,
    required String actingDriverId,
  }) {
    if (!exists) {
      throw const TripServiceException('الرحلة غير موجودة.');
    }
    ensureAssignedDriver(
      assignedDriverId: assignedDriverId,
      actingDriverId: actingDriverId,
    );

    final status = TripStatusExtension.fromString(
      currentStatus ?? TripStatus.pending.stringValue,
    );
    ensureValidStatusTransition(status, TripStatus.cancelled);
  }

  /// بيانات التحديث عند القبول (مرجع للاختبارات / توافق قديم).
  static Map<String, dynamic> acceptanceUpdateFields(String driverId) {
    return {
      'status': TripStatus.active.stringValue,
      'driverId': driverId,
    };
  }

  /// التحقق من صحة الانتقال بين حالات الرحلة (State Machine).
  static void ensureValidStatusTransition(
    TripStatus currentStatus,
    TripStatus newStatus,
  ) {
    switch (currentStatus) {
      case TripStatus.pending:
        if (newStatus != TripStatus.active &&
            newStatus != TripStatus.cancelled) {
          throw TripServiceException(
            'لا يمكن الانتقال من حالة "قيد الانتظار" إلى حالة "${newStatus.stringValue}" مباشرة. '
            'الحالات المسموحة: "نشطة" أو "ملغية".',
          );
        }
        break;

      case TripStatus.active:
        if (newStatus != TripStatus.completed &&
            newStatus != TripStatus.cancelled) {
          throw TripServiceException(
            'لا يمكن الانتقال من حالة "نشطة" إلى حالة "${newStatus.stringValue}" مباشرة. '
            'الحالات المسموحة: "مكتملة" أو "ملغية".',
          );
        }
        break;

      case TripStatus.completed:
        throw const TripServiceException(
          'لا يمكن تغيير حالة رحلة مكتملة. الحالة النهائية: "مكتملة".',
        );

      case TripStatus.cancelled:
        throw const TripServiceException(
          'لا يمكن تغيير حالة رحلة ملغية. الحالة النهائية: "ملغية".',
        );
    }
  }
}
