import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pickup_point_model.dart';

class PickupPointService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('pickup_points');

  // ✅ دالة لجلب النقاط المعلقة (pending)
  Stream<List<PickupPointModel>> getPendingPointsStream() {
    return _collection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PickupPointModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // ✅ دالة لجلب النقاط الموافق عليها (approved) - للاستخدام العام
  Stream<List<PickupPointModel>> getApprovedPointsStream() {
    return _collection
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PickupPointModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // ✅ دالة للموافقة على نقطة (تغيير الحالة إلى approved)
  Future<void> approvePickupPoint(String id) async {
    try {
      await _collection.doc(id).update({'status': 'approved'});
    } catch (e) {
      throw Exception('فشل الموافقة على النقطة: $e');
    }
  }

  // ✅ دالة لرفض نقطة (تغيير الحالة إلى rejected)
  Future<void> rejectPickupPoint(String id) async {
    try {
      await _collection.doc(id).update({'status': 'rejected'});
    } catch (e) {
      throw Exception('فشل رفض النقطة: $e');
    }
  }

  // ✅ دالة لحذف نقطة (إذا لزم الأمر)
  Future<void> deletePickupPoint(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw Exception('فشل حذف النقطة: $e');
    }
  }

  // ✅ دالة لإضافة نقطة (سيتم استخدامها من قبل السائقين)
  Future<void> addPickupPoint(PickupPointModel point) async {
    try {
      await _collection.doc(point.id).set(point.toMap());
    } catch (e) {
      throw Exception('فشل إضافة النقطة: $e');
    }
  }

  // ✅ دالة لجلب عدد النقاط المعلقة (للإحصائيات)
  Future<int> getPendingCount() async {
    try {
      final snapshot =
          await _collection.where('status', isEqualTo: 'pending').get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
