import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserData(UserModel user) async {
    try {
      final data = user.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(user.uid).set(data);
    } catch (e) {
      throw Exception('فشل حفظ بيانات المستخدم: $e');
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب بيانات المستخدم: $e');
    }
  }

  Stream<UserModel?> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      throw Exception('فشل تحديث بيانات المستخدم: $e');
    }
  }

  // ✅ دالة جديدة لرفض السائق
  Future<void> rejectDriver(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isVerified': false,
        'isRejected': true,
      });
    } catch (e) {
      throw Exception('فشل رفض السائق: $e');
    }
  }

  // ✅ دالة للحصول على إحصائيات السائقين (اختيارية، سنستخدمها في التبويب)
  Future<Map<String, int>> getDriversStats() async {
    try {
      final allDrivers = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'driver')
          .get();

      final total = allDrivers.docs.length;
      final verified = allDrivers.docs
          .where((doc) => (doc.data()['isVerified'] ?? false) == true)
          .length;
      final pending = allDrivers.docs
          .where((doc) =>
              (doc.data()['isVerified'] ?? false) == false &&
              (doc.data()['isRejected'] ?? false) == false)
          .length;
      final rejected = allDrivers.docs
          .where((doc) => (doc.data()['isRejected'] ?? false) == true)
          .length;

      return {
        'total': total,
        'verified': verified,
        'pending': pending,
        'rejected': rejected,
      };
    } catch (e) {
      throw Exception('فشل جلب الإحصائيات: $e');
    }
  }
}
