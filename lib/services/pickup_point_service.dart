import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pickup_point_model.dart';
import 'pickup_point_service_exception.dart';

/// خدمة إدارة نقاط التجمع مع Timeout و Retry
class PickupPointService {
  // ✅ توحيد اسم المجموعة (pickupPoints)
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('pickupPoints');

  // ✅ ثوابت Timeout و Retry
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. دوال مساعدة
  // ─────────────────────────────────────────────────────────────────────────────

  /// ✅ دالة مساعدة لتكرار العمليات مع Timeout و Retry
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
          // ❌ لا يمكن استخدام const هنا (لأن الرسالة تحتوي على متغيرات)
          throw PickupPointServiceException(
            'فشلت العملية بعد $retries محاولات: $e',
          );
        }
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
    }
  }

  /// ✅ تحويل DocumentSnapshot إلى PickupPointModel (مع التحقق من null)
  PickupPointModel _docToModel(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      // ✅ يمكن استخدام const هنا لأن الرسالة ثابتة
      throw const PickupPointServiceException('بيانات النقطة غير موجودة');
    }
    return PickupPointModel.fromMap(data, doc.id);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. Streams (قراءة البيانات)
  // ─────────────────────────────────────────────────────────────────────────────

  /// ✅ دالة لجلب النقاط المعلقة (pending)
  Stream<List<PickupPointModel>> getPendingPointsStream() {
    return _collection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToModel).toList());
  }

  /// ✅ دالة لجلب النقاط الموافق عليها (approved)
  Stream<List<PickupPointModel>> getApprovedPointsStream() {
    return _collection
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToModel).toList());
  }

  /// ✅ جلب نقطة تجمع بواسطة المعرف
  Future<PickupPointModel?> getPickupPoint(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return _docToModel(doc);
      }
      return null;
    } catch (e) {
      throw PickupPointServiceException('فشل جلب نقطة التجمع: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. عمليات الكتابة (CRUD)
  // ─────────────────────────────────────────────────────────────────────────────

  /// ✅ إضافة نقطة جديدة (معرف محدد مسبقاً)
  Future<void> addPickupPoint(PickupPointModel point) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(point.id).set(point.toMap());
    });
  }

  /// ✅ إضافة نقطة جديدة مع تعيين الحالة حسب نوع المستخدم
  Future<String> addPickupPointWithRole({
    required PickupPointModel point,
    required String userId,
    required String userType,
  }) async {
    try {
      final docRef = _collection.doc();

      final data = point.toMap();
      data['id'] = docRef.id;
      data['addedBy'] = userId;
      data['addedByUserType'] = userType;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (userType == 'admin') {
        data['status'] = 'approved';
      } else {
        data['status'] = 'pending';
      }

      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      throw PickupPointServiceException('فشل إضافة نقطة التجمع: $e');
    }
  }

  /// ✅ تحديث نقطة تجمع موجودة
  Future<void> updatePickupPoint({
    required String pointId,
    required Map<String, dynamic> data,
  }) async {
    await _withRetryAndTimeout(() async {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _collection.doc(pointId).update(data);
    });
  }

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

  /// ✅ حذف نقطة
  Future<void> deletePickupPoint(String id) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(id).delete();
    });
  }

  /// ✅ تأكيد نقطة تجمع (زيادة عدد التأكيدات)
  Future<void> confirmPickupPoint({
    required String pointId,
    required String userId,
  }) async {
    try {
      final docRef = _collection.doc(pointId);
      await _withRetryAndTimeout(() async {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final doc = await transaction.get(docRef);
          if (!doc.exists) {
            // ✅ يمكن استخدام const هنا لأن الرسالة ثابتة
            throw const PickupPointServiceException('نقطة التجمع غير موجودة');
          }

          final data = doc.data() as Map<String, dynamic>?;
          final confirmations = List<String>.from(data?['confirmations'] ?? []);
          if (confirmations.contains(userId)) {
            return;
          }

          confirmations.add(userId);
          transaction.update(docRef, {
            'confirmations': confirmations,
            'confirmationCount': confirmations.length,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      });
    } catch (e) {
      throw PickupPointServiceException('فشل تأكيد نقطة التجمع: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. إحصائيات
  // ─────────────────────────────────────────────────────────────────────────────

  /// ✅ عدد النقاط المعلقة
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
