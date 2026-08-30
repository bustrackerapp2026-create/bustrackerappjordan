import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vehicle_trip.dart';

/// استثناءات خدمة الرحلات التشغيلية.
class VehicleTripServiceException implements Exception {
  final String message;
  final String? code;

  const VehicleTripServiceException(this.message, {this.code});

  @override
  String toString() => message;
}

/// خدمة إدارة الرحلات التشغيلية (Vehicle Operation).
///
/// منفصلة تمامًا عن [TripService] الخاصة بطلبات الركاب.
/// Collection: vehicleTrips
class VehicleTripService {
  VehicleTripService._();
  static final VehicleTripService instance = VehicleTripService._();
  factory VehicleTripService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('vehicleTrips');

  CollectionReference<Map<String, dynamic>> get _driverLocks =>
      _db.collection('vehicleTripDriverLocks');

  static const Duration _defaultTimeout = Duration(seconds: 12);
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
        if (e is VehicleTripServiceException || e is FormatException) rethrow;
        if (e is FirebaseException &&
            (e.code == 'permission-denied' || e.code == 'not-found')) {
          throw _mapFirebaseError(e);
        }
        attempt++;
        if (attempt >= retries) {
          if (e is FirebaseException) throw _mapFirebaseError(e);
          throw VehicleTripServiceException(
            'فشلت العملية بعد $retries محاولات: $e',
          );
        }
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
      }
    }
  }

  VehicleTripServiceException _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const VehicleTripServiceException(
          'رفض الصلاحيات. تأكد من نشر قواعد vehicleTrips ثم أعد المحاولة.',
          code: 'permission-denied',
        );
      case 'not-found':
        return const VehicleTripServiceException(
          'الرحلة التشغيلية غير موجودة.',
          code: 'not-found',
        );
      case 'unavailable':
        return const VehicleTripServiceException(
          'الخدمة غير متاحة مؤقتًا. تحقق من الاتصال.',
          code: 'unavailable',
        );
      default:
        return VehicleTripServiceException(
          'خطأ Firebase (${e.code}): ${e.message}',
          code: e.code,
        );
    }
  }

  /// يتحقق مما إذا كان للسائق رحلة تشغيلية نشطة حاليًا.
  Future<VehicleTrip?> findActiveTripForDriver(String driverId) async {
    if (driverId.isEmpty) return null;

    final snap = await _col
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: VehicleTripStatus.active.firestoreValue)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return VehicleTrip.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// يبدأ رحلة تشغيلية جديدة.
  ///
  /// القواعد:
  /// - لا يُنشأ إن وُجدت رحلة ACTIVE لنفس السائق.
  /// - [routeId] يجب أن يشير إلى PlannedRoute معتمد (التحقق يتم قبل الاستدعاء).
  /// - [direction] قيمته outbound أو return.
  /// - لا يُفعَّل DriverProvider قبل نجاح هذه العملية.
  Future<VehicleTrip> startTrip({
    required String driverId,
    required String busNumber,
    required String routeId,
    required String direction,
    GeoPoint? currentLocation,
    double? speed,
    double? heading,
  }) async {
    if (driverId.isEmpty) {
      throw const VehicleTripServiceException('معرف السائق مطلوب.');
    }
    if (routeId.isEmpty) {
      throw const VehicleTripServiceException('معرف المسار مطلوب.');
    }

    final normalizedDirection = _parseDirectionForStart(direction);
    final docRef = _col.doc();
    final lockRef = _driverLocks.doc(driverId);
    final trip = VehicleTrip(
      id: docRef.id,
      driverId: driverId,
      busNumber: busNumber.trim().isEmpty ? '—' : busNumber.trim(),
      routeId: routeId,
      direction: normalizedDirection,
      status: VehicleTripStatus.active,
      currentLocation: currentLocation,
      speed: speed,
      heading: heading,
    );

    await _withRetryAndTimeout(() async {
      await _db.runTransaction((transaction) async {
        final lockSnap = await transaction.get(lockRef);
        if (lockSnap.exists) {
          final existingId = lockSnap.data()?['tripId']?.toString();
          throw VehicleTripServiceException(
            existingId == null || existingId.isEmpty
                ? 'لديك رحلة تشغيلية نشطة بالفعل. أنهِها قبل بدء رحلة جديدة.'
                : 'لديك رحلة تشغيلية نشطة بالفعل ($existingId). أنهِها قبل بدء رحلة جديدة.',
            code: 'already-active',
          );
        }

        transaction.set(lockRef, {
          'driverId': driverId,
          'tripId': docRef.id,
          'status': VehicleTripStatus.active.firestoreValue,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(docRef, trip.toCreateMap());
      });
    });

    return trip;
  }

  VehicleTripServiceException _invalidDirection(String value) =>
      VehicleTripServiceException(
        'اتجاه الرحلة غير صالح: $value. استخدم outbound أو return.',
        code: 'invalid-direction',
      );

  String _parseDirectionForStart(String value) {
    try {
      return VehicleTrip.parseDirection(value);
    } on FormatException {
      throw _invalidDirection(value);
    }
  }

  /// إنهاء رحلة تشغيلية (ACTIVE → COMPLETED).
  Future<void> completeTrip({
    required String tripId,
    required String driverId,
  }) async {
    await _transitionToTerminal(
      tripId: tripId,
      driverId: driverId,
      target: VehicleTripStatus.completed,
    );
  }

  /// إلغاء رحلة تشغيلية (ACTIVE → CANCELLED).
  Future<void> cancelTrip({
    required String tripId,
    required String driverId,
  }) async {
    await _transitionToTerminal(
      tripId: tripId,
      driverId: driverId,
      target: VehicleTripStatus.cancelled,
    );
  }

  Future<void> _transitionToTerminal({
    required String tripId,
    required String driverId,
    required VehicleTripStatus target,
  }) async {
    if (tripId.isEmpty || driverId.isEmpty) {
      throw const VehicleTripServiceException('بيانات العملية غير مكتملة.');
    }
    if (!target.isTerminal) {
      throw const VehicleTripServiceException('الحالة المستهدفة غير نهائية.');
    }

    await _withRetryAndTimeout(() async {
      await _db.runTransaction((transaction) async {
        final docRef = _col.doc(tripId);
        final lockRef = _driverLocks.doc(driverId);
        final snap = await transaction.get(docRef);
        final lockSnap = await transaction.get(lockRef);
        if (!snap.exists || snap.data() == null) {
          throw const VehicleTripServiceException(
            'الرحلة التشغيلية غير موجودة.',
            code: 'not-found',
          );
        }

        final data = snap.data()!;
        final tripDriverId = data['driverId']?.toString() ?? '';
        if (tripDriverId != driverId) {
          throw const VehicleTripServiceException(
            'غير مصرح لك بتعديل هذه الرحلة التشغيلية.',
            code: 'permission-denied',
          );
        }

        final current =
            VehicleTripStatusX.fromString(data['status']?.toString());
        final lockTripId = lockSnap.data()?['tripId']?.toString();
        if (current.isTerminal) {
          if (lockTripId == tripId) transaction.delete(lockRef);
          return;
        }
        if (current != VehicleTripStatus.active) {
          throw VehicleTripServiceException(
            'لا يمكن تحويل الرحلة من ${current.firestoreValue} إلى ${target.firestoreValue}.',
          );
        }

        transaction.update(docRef, {
          'status': target.firestoreValue,
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (lockTripId == tripId) transaction.delete(lockRef);
      });
    });
  }

  /// يجلب رحلة تشغيلية بالمعرّف.
  Future<VehicleTrip?> getTrip(String tripId) async {
    if (tripId.isEmpty) return null;
    final snap = await _col.doc(tripId).get();
    if (!snap.exists || snap.data() == null) return null;
    return VehicleTrip.fromMap(snap.data()!, snap.id);
  }

  /// يراقب الرحلة التشغيلية النشطة للسائق (إن وُجدت).
  Stream<VehicleTrip?> watchActiveTripForDriver(String driverId) {
    if (driverId.isEmpty) {
      return Stream.value(null);
    }
    return _col
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: VehicleTripStatus.active.firestoreValue)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return VehicleTrip.fromMap(snap.docs.first.data(), snap.docs.first.id);
    });
  }
}
