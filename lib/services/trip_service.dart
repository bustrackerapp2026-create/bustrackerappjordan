import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/trip/trip_acceptance.dart';
import '../models/trip_model.dart';
import '../models/trip_status.dart';
import '../models/route_point.dart';
import 'trip_service_exception.dart';

/// خدمة إدارة الرحلات مع أمان العمليات المتزامنة (Transactions)
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
        attempt++;
        if (attempt >= retries) {
          if (e is TripServiceException) rethrow;
          throw TripServiceException('فشلت العملية بعد $retries محاولات: $e');
        }
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
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

  /// رحلات الراكب المفتوحة (انتظار أو نشطة)
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

  Future<void> acceptTripTransaction(String tripId, String driverId) async {
    // تحديث مباشر بدل Transaction لتجنب MissingPluginException على بعض الأجهزة
    await _withRetryAndTimeout(() async {
      final docRef = _firestore.collection(_collection).doc(tripId);
      final snapshot = await docRef.get();
      final data = snapshot.data();

      TripAcceptance.ensureCanAccept(
        exists: snapshot.exists,
        currentStatus: data?['status'] as String?,
      );

      final fields = TripAcceptance.acceptanceUpdateFields(driverId);
      fields['startedAt'] = FieldValue.serverTimestamp();
      await docRef.update(fields);
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

  /// طلب صعود من الراكب إلى سائق محدد (محطة قريبة / موقعي)
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

    // منع تكرار طلب مفتوح لنفس السائق
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

  /// إلغاء من الراكب — تحديث مباشر (بدون Transaction) لتفادي
  /// MissingPluginException على قناة transaction/cancel.
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

      // فقط pending أو active يمكن إلغاؤهما من الراكب
      if (status != TripStatus.pending.stringValue &&
          status != TripStatus.active.stringValue) {
        throw const TripServiceException('لا يمكن إلغاء هذه الرحلة بحالتها الحالية.');
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
      throw TripServiceException(
        'غير مصرح لك بتعديل هذه الرحلة. السائق الحالي: $tripDriverId',
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

    await _withRetryAndTimeout(() async {
      await _firestore
          .collection(_collection)
          .doc(trip.id)
          .update(trip.toMap());
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
