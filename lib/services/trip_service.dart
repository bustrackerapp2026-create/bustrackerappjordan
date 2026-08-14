import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/trip/trip_acceptance.dart';
import '../models/trip_model.dart';
import '../models/trip_status.dart';
import '../models/route_point.dart';
import 'trip_service_exception.dart';

/// خدمة إدارة الرحلات — قبول/إلغاء بدون Transaction (توافق أجهزة MIUI).
class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'trips';

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
        // لا نعيد محاولة أخطاء الصلاحيات / المنطق — تفشل فوراً
        if (e is TripServiceException) rethrow;
        if (e is FirebaseException &&
            (e.code == 'permission-denied' || e.code == 'not-found')) {
          throw _mapFirebaseError(e);
        }
        attempt++;
        if (attempt >= retries) {
          if (e is FirebaseException) throw _mapFirebaseError(e);
          throw TripServiceException('فشلت العملية بعد $retries محاولات: $e');
        }
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
    }
  }

  TripServiceException _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const TripServiceException(
          'رفض الصلاحيات. تأكد من نشر firestore.rules ثم أعد المحاولة.',
        );
      case 'not-found':
        return const TripServiceException('الرحلة غير موجودة.');
      case 'unavailable':
        return const TripServiceException(
          'الخدمة غير متاحة مؤقتاً. تحقق من الاتصال.',
        );
      default:
        return TripServiceException('خطأ Firebase (${e.code}): ${e.message}');
    }
  }

  List<TripModel> _mapDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final out = <TripModel>[];
    for (final doc in docs) {
      try {
        out.add(TripModel.fromMap(doc.data(), doc.id));
      } catch (_) {}
    }
    return out;
  }

  Stream<List<TripModel>> getPassengerTrips(String passengerId) {
    return _firestore
        .collection(_collection)
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapDocs(snapshot.docs));
  }

  Stream<List<TripModel>> watchPassengerOpenTrips(String passengerId) {
    return _firestore
        .collection(_collection)
        .where('passengerId', isEqualTo: passengerId)
        .where('status', whereIn: [
          TripStatus.pending.stringValue,
          TripStatus.active.stringValue,
        ])
        .snapshots()
        .map((snapshot) {
      final list = _mapDocs(snapshot.docs);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<TripModel?> watchTrip(String tripId) {
    return _firestore.collection(_collection).doc(tripId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      try {
        return TripModel.fromMap(doc.data()!, doc.id);
      } catch (_) {
        return null;
      }
    });
  }

  Stream<List<TripModel>> getDriverTrips(String driverId) {
    return _firestore
        .collection(_collection)
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapDocs(snapshot.docs));
  }

  Stream<List<TripModel>> getActiveDriverTrips(String driverId) {
    return _firestore
        .collection(_collection)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: TripStatus.active.stringValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapDocs(snapshot.docs));
  }

  Stream<List<TripModel>> getPastDriverTrips(String driverId) {
    return _firestore
        .collection(_collection)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          TripStatus.completed.stringValue,
          TripStatus.cancelled.stringValue,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapDocs(snapshot.docs));
  }

  Stream<List<TripModel>> getPendingDriverTrips(String driverId) {
    return _firestore
        .collection(_collection)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: TripStatus.pending.stringValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapDocs(snapshot.docs));
  }

  /// قبول طلب موجّه لهذا السائق (pending → active).
  /// بدون Transaction؛ القواعد تمنع سائقاً آخر من التعديل.
  Future<void> acceptTripTransaction(String tripId, String driverId) async {
    if (tripId.isEmpty || driverId.isEmpty) {
      throw const TripServiceException('بيانات القبول غير مكتملة.');
    }

    await _withRetryAndTimeout(() async {
      final docRef = _firestore.collection(_collection).doc(tripId);
      final snapshot = await docRef.get();
      final data = snapshot.data();

      TripAcceptance.ensureCanAccept(
        exists: snapshot.exists,
        currentStatus: data?['status'] as String?,
      );

      final assigned = data!['driverId'] as String? ?? '';
      if (assigned != driverId) {
        throw const TripServiceException(
          'هذا الطلب موجّه لسائق آخر.',
        );
      }

      // حقول محدودة فقط — متوافقة مع firestore.rules (driverTripUpdateKeys)
      await docRef.update({
        'status': TripStatus.active.stringValue,
        'startedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> createTrip(TripModel trip) async {
    await _withRetryAndTimeout(() async {
      await _firestore
          .collection(_collection)
          .doc(trip.id)
          .set(trip.toCreateMap());
    });
  }

  Future<String> createBoardRequest({
    required String passengerId,
    required String driverId,
    required String pickupPoint,
    required double pickupLat,
    required double pickupLng,
    String? route,
    String? passengerName,
    String? driverName,
    String? busNumber,
    String dropoffPoint = 'على طول الخط',
  }) async {
    if (passengerId.isEmpty || driverId.isEmpty) {
      throw const TripServiceException('معرف الراكب أو السائق مفقود.');
    }

    final existing = await _firestore
        .collection(_collection)
        .where('passengerId', isEqualTo: passengerId)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          TripStatus.pending.stringValue,
          TripStatus.active.stringValue,
        ])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final docRef = _firestore.collection(_collection).doc();
    final trip = TripModel(
      id: docRef.id,
      passengerId: passengerId,
      driverId: driverId,
      pickupPoint: pickupPoint,
      dropoffPoint: dropoffPoint,
      createdAt: DateTime.now(),
      status: TripStatus.pending,
      route: route,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      passengerName: passengerName,
      driverName: driverName,
      busNumber: busNumber,
      notes: 'طلب صعود من الراكب',
    );

    await _withRetryAndTimeout(() async {
      await docRef.set(trip.toCreateMap());
    });
    return docRef.id;
  }

  Future<void> cancelTripByPassenger({
    required String tripId,
    required String passengerId,
  }) async {
    if (tripId.isEmpty || passengerId.isEmpty) {
      throw const TripServiceException('بيانات الإلغاء غير مكتملة.');
    }

    await _withRetryAndTimeout(() async {
      final docRef = _firestore.collection(_collection).doc(tripId);
      final snap = await docRef.get();

      if (!snap.exists || snap.data() == null) {
        throw const TripServiceException('الرحلة غير موجودة.');
      }

      final data = snap.data()!;
      if (data['passengerId'] != passengerId) {
        throw const TripServiceException('غير مصرح بإلغاء هذه الرحلة.');
      }

      final status = data['status'] as String? ?? 'pending';
      if (status == TripStatus.completed.stringValue ||
          status == TripStatus.cancelled.stringValue) {
        return;
      }

      if (status != TripStatus.pending.stringValue &&
          status != TripStatus.active.stringValue) {
        throw const TripServiceException(
          'لا يمكن إلغاء هذه الرحلة بحالتها الحالية.',
        );
      }

      await docRef.update({
        'status': TripStatus.cancelled.stringValue,
        'completedAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'passenger',
      });
    });
  }

  Future<Map<String, dynamic>?> _getTripData(String tripId) async {
    final doc = await _firestore.collection(_collection).doc(tripId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> _verifyOwnership(String tripId, String driverId) async {
    final tripData = await _getTripData(tripId);
    if (tripData == null) {
      throw const TripServiceException('الرحلة غير موجودة.');
    }

    final tripDriverId = tripData['driverId'] as String?;
    if (tripDriverId != driverId) {
      throw const TripServiceException(
        'غير مصرح لك بتعديل هذه الرحلة.',
      );
    }
  }

  Future<void> updateTripStatus(
    String tripId,
    TripStatus newStatus, {
    DateTime? startedAt,
    DateTime? completedAt,
    List<RoutePoint>? routePoints,
    String? driverId,
  }) async {
    if (driverId == null) {
      throw const TripServiceException('معرف السائق مطلوب للتحقق من الملكية.');
    }

    await _verifyOwnership(tripId, driverId);

    final tripData = await _getTripData(tripId);
    if (tripData == null) {
      throw const TripServiceException('الرحلة غير موجودة.');
    }

    final currentStatusString = tripData['status'] as String? ?? 'pending';
    final currentStatus = TripStatusExtension.fromString(currentStatusString);

    TripAcceptance.ensureValidStatusTransition(currentStatus, newStatus);

    await _withRetryAndTimeout(() async {
      final Map<String, dynamic> data = {'status': newStatus.stringValue};

      if (startedAt != null) {
        data['startedAt'] = Timestamp.fromDate(startedAt);
      } else if (newStatus == TripStatus.active) {
        data['startedAt'] = FieldValue.serverTimestamp();
      }

      if (completedAt != null) {
        data['completedAt'] = Timestamp.fromDate(completedAt);
      } else if (newStatus == TripStatus.completed ||
          newStatus == TripStatus.cancelled) {
        data['completedAt'] = FieldValue.serverTimestamp();
      }

      if (newStatus == TripStatus.cancelled) {
        data['cancelledBy'] = 'driver';
      }

      if (routePoints != null && routePoints.isNotEmpty) {
        data['routePoints'] = routePoints.map((p) => p.toMap()).toList();
      }

      await _firestore.collection(_collection).doc(tripId).update(data);
    });
  }

  Future<void> updateTrip(
    TripModel trip, {
    String? driverId,
  }) async {
    if (driverId == null) {
      throw const TripServiceException('معرف السائق مطلوب للتحقق من الملكية.');
    }

    await _verifyOwnership(trip.id, driverId);

    // تحديث محدود الحقول ليتوافق مع القواعد
    await _withRetryAndTimeout(() async {
      final data = <String, dynamic>{
        'status': trip.status.stringValue,
        if (trip.notes != null) 'notes': trip.notes,
        if (trip.startedAt != null)
          'startedAt': Timestamp.fromDate(trip.startedAt!),
        if (trip.completedAt != null)
          'completedAt': Timestamp.fromDate(trip.completedAt!),
        if (trip.routePoints != null && trip.routePoints!.isNotEmpty)
          'routePoints': trip.routePoints!.map((p) => p.toMap()).toList(),
      };
      await _firestore.collection(_collection).doc(trip.id).update(data);
    });
  }

  Future<void> deleteTrip(
    String tripId, {
    String? driverId,
  }) async {
    if (driverId == null) {
      throw const TripServiceException('معرف السائق مطلوب للتحقق من الملكية.');
    }

    await _verifyOwnership(tripId, driverId);

    await _withRetryAndTimeout(() async {
      await _firestore.collection(_collection).doc(tripId).delete();
    });
  }

  Future<int> getPendingCountForDriver(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: TripStatus.pending.stringValue)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
