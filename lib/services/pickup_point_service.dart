import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pickup_point_model.dart';
import 'pickup_point_service_exception.dart';

/// خدمة إدارة نقاط التجمع مع Timeout و Retry
class PickupPointService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('pickup_points');

  // ✅ ثوابت Timeout و Retry
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;

  // ============================================================
  // ✅ دالة مساعدة لتكرار العمليات مع Timeout و Retry
  // ============================================================

  Future<T> _withRetryAndTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = _defaultTimeout,
    int retries = _maxRetries,
  }) async {
    int attempt = 0;
    Duration delay = const Duration(milliseconds: 500);

    while (true) {
      try {
        return await operation().timeout(timeout);
      } catch (e) {
        attempt++;
        if (attempt >= retries) {
          if (e is PickupPointServiceException) rethrow;
          throw PickupPointServiceException(
            'فشلت العملية بعد $retries محاولات: $e',
          );
        }
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
    }
  }

  // ─── Streams ───────────────────────────────────────────────

  /// ✅ دالة لجلب النقاط المعلقة (pending)
  Stream<List<PickupPointModel>> getPendingPointsStream() {
    return _collection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PickupPointModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  /// ✅ دالة لجلب النقاط الموافق عليها (approved)
  Stream<List<PickupPointModel>> getApprovedPointsStream() {
    return _collection
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PickupPointModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // ─── عمليات الكتابة (مع Timeout و Retry) ──────────────────

  /// ✅ الموافقة على نقطة (تغيير الحالة إلى approved)
  Future<void> approvePickupPoint(String id) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(id).update({'status': 'approved'});
    });
  }

  /// ✅ رفض نقطة (تغيير الحالة إلى rejected)
  Future<void> rejectPickupPoint(String id) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(id).update({'status': 'rejected'});
    });
  }

  /// ✅ حذف نقطة (إذا لزم الأمر)
  Future<void> deletePickupPoint(String id) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(id).delete();
    });
  }

  /// ✅ إضافة نقطة جديدة
  Future<void> addPickupPoint(PickupPointModel point) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(point.id).set(point.toMap());
    });
  }

  // ─── إحصائيات ───────────────────────────────────────────────

  /// ✅ عدد النقاط المعلقة (باستخدام count() لتوفير التكلفة)
  Future<int> getPendingCount() async {
    try {
      final snapshot =
          await _collection.where('status', isEqualTo: 'pending').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// ✅ عدد النقاط المعتمدة
  Future<int> getApprovedCount() async {
    try {
      final snapshot = await _collection
          .where('status', isEqualTo: 'approved')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// ✅ عدد النقاط المرفوضة
  Future<int> getRejectedCount() async {
    try {
      final snapshot = await _collection
          .where('status', isEqualTo: 'rejected')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
