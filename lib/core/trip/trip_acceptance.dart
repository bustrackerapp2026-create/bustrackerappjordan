import '../../models/trip_status.dart';
import '../../services/trip_service_exception.dart';

/// قواعد قبول الرحلة وانتقال الحالات — منطق نقي قابل للاختبار بدون Firebase.
class TripAcceptance {
  const TripAcceptance._();

  /// هل يمكن قبول الرحلة بحالتها الحالية؟
  static bool canAccept({required String? currentStatus}) {
    return currentStatus == TripStatus.pending.stringValue;
  }

  /// يتحقق قبل قبول الرحلة داخل Transaction.
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

  /// بيانات التحديث عند القبول الناجح.
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
