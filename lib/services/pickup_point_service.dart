import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pickup_point_model.dart';
import 'pickup_point_service_exception.dart';

/// نتيجة ترحيل توحيد حالات النقاط
class PickupStatusMigrationResult {
  final int total;
  final int setApproved;
  final int setPending;
  final int setRejected;
  final int unchanged;
  final int failed;

  const PickupStatusMigrationResult({
    required this.total,
    required this.setApproved,
    required this.setPending,
    required this.setRejected,
    required this.unchanged,
    required this.failed,
  });

  @override
  String toString() =>
      'إجمالي: $total | معتمدة: $setApproved | معلقة: $setPending | مرفوضة: $setRejected | دون تغيير: $unchanged | فشل: $failed';
}

/// خدمة إدارة نقاط التجمع مع Timeout و Retry
class PickupPointService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('pickupPoints');

  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;

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

  PickupPointModel _docToModel(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw const PickupPointServiceException('بيانات النقطة غير موجودة');
    }
    return PickupPointModel.fromMap(data, doc.id);
  }

  Stream<List<PickupPointModel>> getPendingPointsStream() {
    return _collection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToModel).toList());
  }

  Stream<List<PickupPointModel>> getApprovedPointsStream() {
    return _collection
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToModel).toList());
  }

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

  Future<void> addPickupPoint(PickupPointModel point) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(point.id).set(point.toMap());
    });
  }

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
        data['isApproved'] = true;
      } else {
        data['status'] = 'pending';
        data['isApproved'] = false;
      }

      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      throw PickupPointServiceException('فشل إضافة نقطة التجمع: $e');
    }
  }

  Future<void> updatePickupPoint({
    required String pointId,
    required Map<String, dynamic> data,
  }) async {
    await _withRetryAndTimeout(() async {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _collection.doc(pointId).update(data);
    });
  }

  /// الموافقة: توحيد الحقول إلى status=approved
  Future<void> approvePickupPoint(String id) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(id).update({
        'status': 'approved',
        'isApproved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectPickupPoint(String id) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(id).update({
        'status': 'rejected',
        'isApproved': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deletePickupPoint(String id) async {
    await _withRetryAndTimeout(() async {
      await _collection.doc(id).delete();
    });
  }

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

  /// ترحيل لمرة واحدة: توحيد status لكل المستندات في pickupPoints.
  /// - pending / rejected تبقى كما هي (مع ضبط isApproved).
  /// - approved أو isApproved=true أو بدون status بإحداثيات صالحة → approved.
  /// للأدمن فقط (عبر قواعد Firestore).
  Future<PickupStatusMigrationResult> migrateNormalizeStatuses() async {
    final snapshot = await _collection.get();
    var setApproved = 0;
    var setPending = 0;
    var setRejected = 0;
    var unchanged = 0;
    var failed = 0;

    // دفعات كتابة (حد Firestore ~500 عملية/batch)
    WriteBatch? batch = FirebaseFirestore.instance.batch();
    var opsInBatch = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (batch == null) return;
      if (opsInBatch == 0) return;
      if (!force && opsInBatch < 400) return;
      await batch!.commit();
      batch = FirebaseFirestore.instance.batch();
      opsInBatch = 0;
    }

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final rawStatus = data['status']?.toString().trim().toLowerCase();
        final isApprovedFlag = data['isApproved'] == true;

        String target;
        if (rawStatus == 'rejected') {
          target = 'rejected';
        } else if (rawStatus == 'pending') {
          target = 'pending';
        } else if (rawStatus == 'approved' || isApprovedFlag) {
          target = 'approved';
        } else if (rawStatus == null || rawStatus.isEmpty) {
          // بيانات قديمة بلا status: إن وُجدت إحداثيات صالحة نعتبرها معتمدة
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          if (lat != null &&
              lng != null &&
              (lat != 0.0 || lng != 0.0) &&
              data['isApproved'] != false) {
            target = 'approved';
          } else {
            target = 'pending';
          }
        } else {
          // قيم غريبة → pending للمراجعة
          target = 'pending';
        }

        final alreadyOk = rawStatus == target &&
            (target == 'approved'
                ? isApprovedFlag == true
                : data['isApproved'] != true || target != 'approved');

        // نحدّث دائماً إذا status غير مطابق أو isApproved غير متسق
        final needUpdate = rawStatus != target ||
            (target == 'approved' && !isApprovedFlag) ||
            (target != 'approved' && isApprovedFlag);

        if (!needUpdate) {
          unchanged++;
          continue;
        }

        batch!.update(doc.reference, {
          'status': target,
          'isApproved': target == 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        opsInBatch++;

        if (target == 'approved') {
          setApproved++;
        } else if (target == 'pending') {
          setPending++;
        } else {
          setRejected++;
        }

        await commitIfNeeded();
      } catch (_) {
        failed++;
      }
    }

    await commitIfNeeded(force: true);

    return PickupStatusMigrationResult(
      total: snapshot.docs.length,
      setApproved: setApproved,
      setPending: setPending,
      setRejected: setRejected,
      unchanged: unchanged,
      failed: failed,
    );
  }

  Future<int> getPendingCount() async {
    try {
      final snapshot =
          await _collection.where('status', isEqualTo: 'pending').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

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
