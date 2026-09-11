import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vehicle_trip.dart';

/// ╪º╪│╪¬╪½┘å╪º╪í╪º╪¬ ╪«╪»┘à╪⌐ ╪º┘ä╪▒╪¡┘ä╪º╪¬ ╪º┘ä╪¬╪┤╪║┘è┘ä┘è╪⌐.
class VehicleTripServiceException implements Exception {
  final String message;
  final String? code;

  const VehicleTripServiceException(this.message, {this.code});

  @override
  String toString() => message;
}

/// ╪«╪»┘à╪⌐ ╪Ñ╪»╪º╪▒╪⌐ ╪º┘ä╪▒╪¡┘ä╪º╪¬ ╪º┘ä╪¬╪┤╪║┘è┘ä┘è╪⌐ (Vehicle Operation).
///
/// ┘à┘å┘ü╪╡┘ä╪⌐ ╪¬┘à╪º┘à┘ï╪º ╪╣┘å [TripService] ╪º┘ä╪«╪º╪╡╪⌐ ╪¿╪╖┘ä╪¿╪º╪¬ ╪º┘ä╪▒┘â╪º╪¿.
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
            '┘ü╪┤┘ä╪¬ ╪º┘ä╪╣┘à┘ä┘è╪⌐ ╪¿╪╣╪» $retries ┘à╪¡╪º┘ê┘ä╪º╪¬: $e',
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
          '╪▒┘ü╪╢ ╪º┘ä╪╡┘ä╪º╪¡┘è╪º╪¬. ╪¬╪ú┘â╪» ┘à┘å ┘å╪┤╪▒ ┘é┘ê╪º╪╣╪» vehicleTrips ╪½┘à ╪ú╪╣╪» ╪º┘ä┘à╪¡╪º┘ê┘ä╪⌐.',
          code: 'permission-denied',
        );
      case 'not-found':
        return const VehicleTripServiceException(
          '╪º┘ä╪▒╪¡┘ä╪⌐ ╪º┘ä╪¬╪┤╪║┘è┘ä┘è╪⌐ ╪║┘è╪▒ ┘à┘ê╪¼┘ê╪»╪⌐.',
          code: 'not-found',
        );
      case 'unavailable':
        return const VehicleTripServiceException(
          '╪º┘ä╪«╪»┘à╪⌐ ╪║┘è╪▒ ┘à╪¬╪º╪¡╪⌐ ┘à╪ñ┘é╪¬┘ï╪º. ╪¬╪¡┘é┘é ┘à┘å ╪º┘ä╪º╪¬╪╡╪º┘ä.',
          code: 'unavailable',
        );
      default:
        return VehicleTripServiceException(
          '╪«╪╖╪ú Firebase (${e.code}): ${e.message}',
          code: e.code,
        );
    }
  }

  /// ┘è╪¬╪¡┘é┘é ┘à┘à╪º ╪Ñ╪░╪º ┘â╪º┘å ┘ä┘ä╪│╪º╪ª┘é ╪▒╪¡┘ä╪⌐ ╪¬╪┤╪║┘è┘ä┘è╪⌐ ┘å╪┤╪╖╪⌐ ╪¡╪º┘ä┘è┘ï╪º.
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

  /// ┘è╪¿╪»╪ú ╪▒╪¡┘ä╪⌐ ╪¬╪┤╪║┘è┘ä┘è╪⌐ ╪¼╪»┘è╪»╪⌐.
  ///
  /// ╪º┘ä┘é┘ê╪º╪╣╪»:
  /// - ┘ä╪º ┘è┘Å┘å╪┤╪ú ╪Ñ┘å ┘ê┘Å╪¼╪»╪¬ ╪▒╪¡┘ä╪⌐ ACTIVE ┘ä┘å┘ü╪│ ╪º┘ä╪│╪º╪ª┘é.
  /// - [routeId] ┘è╪¼╪¿ ╪ú┘å ┘è╪┤┘è╪▒ ╪Ñ┘ä┘ë PlannedRoute ┘à╪╣╪¬┘à╪» (╪º┘ä╪¬╪¡┘é┘é ┘è╪¬┘à ┘é╪¿┘ä ╪º┘ä╪º╪│╪¬╪»╪╣╪º╪í).
  /// - [direction] ┘é┘è┘à╪¬┘ç outbound ╪ú┘ê return.
  /// - ┘ä╪º ┘è┘Å┘ü╪╣┘æ┘Ä┘ä DriverProvider ┘é╪¿┘ä ┘å╪¼╪º╪¡ ┘ç╪░┘ç ╪º┘ä╪╣┘à┘ä┘è╪⌐.
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
      throw const VehicleTripServiceException('┘à╪╣╪▒┘ü ╪º┘ä╪│╪º╪ª┘é ┘à╪╖┘ä┘ê╪¿.');
    }
    if (routeId.isEmpty) {
      throw const VehicleTripServiceException('┘à╪╣╪▒┘ü ╪º┘ä┘à╪│╪º╪▒ ┘à╪╖┘ä┘ê╪¿.');
    }

    final normalizedDirection = _parseDirectionForStart(direction);
    final docRef = _col.doc();
    final lockRef = _driverLocks.doc(driverId);
    final trip = VehicleTrip(
      id: docRef.id,
      driverId: driverId,
      busNumber: busNumber.trim().isEmpty ? 'ΓÇö' : busNumber.trim(),
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
                ? '┘ä╪»┘è┘â ╪▒╪¡┘ä╪⌐ ╪¬╪┤╪║┘è┘ä┘è╪⌐ ┘å╪┤╪╖╪⌐ ╪¿╪º┘ä┘ü╪╣┘ä. ╪ú┘å┘ç┘É┘ç╪º ┘é╪¿┘ä ╪¿╪»╪í ╪▒╪¡┘ä╪⌐ ╪¼╪»┘è╪»╪⌐.'
                : '┘ä╪»┘è┘â ╪▒╪¡┘ä╪⌐ ╪¬╪┤╪║┘è┘ä┘è╪⌐ ┘å╪┤╪╖╪⌐ ╪¿╪º┘ä┘ü╪╣┘ä ($existingId). ╪ú┘å┘ç┘É┘ç╪º ┘é╪¿┘ä ╪¿╪»╪í ╪▒╪¡┘ä╪⌐ ╪¼╪»┘è╪»╪⌐.',
            code: 'active-trip-exists',
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
        '╪º╪¬╪¼╪º┘ç ╪º┘ä╪▒╪¡┘ä╪⌐ ╪║┘è╪▒ ╪╡╪º┘ä╪¡: $value. ╪º╪│╪¬╪«╪»┘à outbound ╪ú┘ê return.',
        code: 'invalid-direction',
      );

  String _parseDirectionForStart(String value) {
    try {
      return VehicleTrip.parseDirection(value);
    } on FormatException {
      throw _invalidDirection(value);
    }
  }

  /// ╪Ñ┘å┘ç╪º╪í ╪▒╪¡┘ä╪⌐ ╪¬╪┤╪║┘è┘ä┘è╪⌐ (ACTIVE ΓåÆ COMPLETED).
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

  /// ╪Ñ┘ä╪║╪º╪í ╪▒╪¡┘ä╪⌐ ╪¬╪┤╪║┘è┘ä┘è╪⌐ (ACTIVE ΓåÆ CANCELLED).
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
      throw const VehicleTripServiceException('╪¿┘è╪º┘å╪º╪¬ ╪º┘ä╪╣┘à┘ä┘è╪⌐ ╪║┘è╪▒ ┘à┘â╪¬┘à┘ä╪⌐.');
    }
    if (!target.isTerminal) {
      throw const VehicleTripServiceException('╪º┘ä╪¡╪º┘ä╪⌐ ╪º┘ä┘à╪│╪¬┘ç╪»┘ü╪⌐ ╪║┘è╪▒ ┘å┘ç╪º╪ª┘è╪⌐.');
    }

    await _withRetryAndTimeout(() async {
      await _db.runTransaction((transaction) async {
        final docRef = _col.doc(tripId);
        final lockRef = _driverLocks.doc(driverId);
        final snap = await transaction.get(docRef);
        final lockSnap = await transaction.get(lockRef);
        if (!snap.exists || snap.data() == null) {
          throw const VehicleTripServiceException(
            '╪º┘ä╪▒╪¡┘ä╪⌐ ╪º┘ä╪¬╪┤╪║┘è┘ä┘è╪⌐ ╪║┘è╪▒ ┘à┘ê╪¼┘ê╪»╪⌐.',
            code: 'not-found',
          );
        }

        final data = snap.data()!;
        final tripDriverId = data['driverId']?.toString() ?? '';
        if (tripDriverId != driverId) {
          throw const VehicleTripServiceException(
            '╪║┘è╪▒ ┘à╪╡╪▒╪¡ ┘ä┘â ╪¿╪¬╪╣╪»┘è┘ä ┘ç╪░┘ç ╪º┘ä╪▒╪¡┘ä╪⌐ ╪º┘ä╪¬╪┤╪║┘è┘ä┘è╪⌐.',
            code: 'permission-denied',
          );
        }

        final current =
            VehicleTripStatusX.fromString(data['status']?.toString());
        final lockTripId = lockSnap.data()?['tripId']?.toString();
        if (current.isTerminal) {
          if (lockTripId == tripId || !lockSnap.exists) transaction.delete(lockRef);
          return;
        }
        if (current != VehicleTripStatus.active) {
          throw const VehicleTripServiceException(
            'حالة الرحلة الحالية غير صالحة للانتقال.',
            code: 'invalid-transition',
          );
        }

        transaction.update(docRef, {
          'status': target.firestoreValue,
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (lockTripId == tripId || !lockSnap.exists) transaction.delete(lockRef);
      });
    });
  }

  /// ┘è╪¼┘ä╪¿ ╪▒╪¡┘ä╪⌐ ╪¬╪┤╪║┘è┘ä┘è╪⌐ ╪¿╪º┘ä┘à╪╣╪▒┘æ┘ü.
  Future<VehicleTrip?> getById(String tripId) async {
    if (tripId.isEmpty) return null;
    final snap = await _col.doc(tripId).get();
    if (!snap.exists || snap.data() == null) return null;
    return VehicleTrip.fromMap(snap.data()!, snap.id);
  }

  /// ┘è╪▒╪º┘é╪¿ ╪º┘ä╪▒╪¡┘ä╪⌐ ╪º┘ä╪¬╪┤╪║┘è┘ä┘è╪⌐ ╪º┘ä┘å╪┤╪╖╪⌐ ┘ä┘ä╪│╪º╪ª┘é (╪Ñ┘å ┘ê┘Å╪¼╪»╪¬).
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

