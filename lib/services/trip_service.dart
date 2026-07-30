import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_model.dart';
import '../models/trip_status.dart';

/// خدمة لإدارة عمليات الرحلات مع Firestore.
class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'trips';

  // ─── Streams ───────────────────────────────────────────────

  /// دفق رحلات الراكب (حسب passengerId)
  Stream<List<TripModel>> getPassengerTrips(String passengerId) {
    return _firestore
        .collection(_collection)
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// دفق عمليات السائق (حسب driverId)
  Stream<List<TripModel>> getDriverTrips(String driverId) {
    return _firestore
        .collection(_collection)
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// دفق الرحلات النشطة للسائق (حالة active)
  Stream<List<TripModel>> getActiveDriverTrips(String driverId) {
    return _firestore
        .collection(_collection)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: TripStatus.active.stringValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// دفق الرحلات السابقة للسائق (المكتملة أو الملغية فقط)
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
        .map((snapshot) => snapshot.docs
            .map((doc) => TripModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── عمليات الكتابة ─────────────────────────────────────────

  /// إنشاء رحلة جديدة
  Future<void> createTrip(TripModel trip) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(trip.id)
          .set(trip.toCreateMap());
    } catch (e) {
      throw Exception('فشل إنشاء الرحلة: $e');
    }
  }

  /// ✅ تحديث حالة الرحلة (باستخدام TripStatus enum)
  /// مع إضافة وقت السيرفر تلقائياً عند إنهاء الرحلة
  Future<void> updateTripStatus(
    String tripId,
    TripStatus newStatus, {
    DateTime? startedAt,
    DateTime? completedAt,
  }) async {
    try {
      final Map<String, dynamic> data = {'status': newStatus.stringValue};
      if (startedAt != null) {
        data['startedAt'] = Timestamp.fromDate(startedAt);
      }

      // ✅ تحسين: إذا كانت الحالة "مكتملة" ولم يتم تمرير وقت محدد، نستخدم وقت السيرفر
      if (completedAt != null) {
        data['completedAt'] = Timestamp.fromDate(completedAt);
      } else if (newStatus == TripStatus.completed) {
        data['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection(_collection).doc(tripId).update(data);
    } catch (e) {
      throw Exception('فشل تحديث حالة الرحلة: $e');
    }
  }

  /// تحديث بيانات الرحلة بالكامل
  Future<void> updateTrip(TripModel trip) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(trip.id)
          .update(trip.toMap());
    } catch (e) {
      throw Exception('فشل تحديث الرحلة: $e');
    }
  }

  /// حذف رحلة (للإدارة فقط)
  Future<void> deleteTrip(String tripId) async {
    try {
      await _firestore.collection(_collection).doc(tripId).delete();
    } catch (e) {
      throw Exception('فشل حذف الرحلة: $e');
    }
  }

  // ─── إحصائيات ───────────────────────────────────────────────

  /// عدد الرحلات المعلقة (للسائق)
  Future<int> getPendingCountForDriver(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: TripStatus.pending.stringValue)
          .count()
          .get();
      if (snapshot.count != null) {
        return snapshot.count!;
      } else {
        return 0;
      }
    } catch (_) {
      return 0;
    }
  }
}
