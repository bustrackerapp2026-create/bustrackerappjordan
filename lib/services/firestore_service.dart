import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Users ───────────────────────────────────────────────────────

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

  // ─── إحصائيات السائقين ─────────────────────────────────────────

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

  // ─── إحصائيات جميع المستخدمين ──────────────────────────────────

  Future<Map<String, int>> getAllUsersStats() async {
    try {
      final allUsers = await _firestore.collection('users').get();
      final docs = allUsers.docs;

      final total = docs.length;
      final passenger =
          docs.where((doc) => doc['userType'] == 'passenger').length;
      final driver = docs.where((doc) => doc['userType'] == 'driver').length;
      final service = docs.where((doc) => doc['userType'] == 'service').length;
      final busCompany =
          docs.where((doc) => doc['userType'] == 'bus_company').length;

      final driversOnly = docs.where((doc) => doc['userType'] == 'driver');
      final verified =
          driversOnly.where((doc) => doc['isVerified'] == true).length;
      final pending = driversOnly
          .where(
              (doc) => doc['isVerified'] == false && doc['isRejected'] == false)
          .length;
      final rejected =
          driversOnly.where((doc) => doc['isRejected'] == true).length;

      return {
        'total': total,
        'passenger': passenger,
        'driver': driver,
        'service': service,
        'bus_company': busCompany,
        'verified': verified,
        'pending': pending,
        'rejected': rejected,
      };
    } catch (e) {
      throw Exception('فشل جلب إحصائيات المستخدمين: $e');
    }
  }

  // ─── إحصائيات نقاط التجمع ──────────────────────────────────────

  Future<Map<String, int>> getPickupPointsStats() async {
    try {
      final allPoints = await _firestore.collection('pickupPoints').get();
      final docs = allPoints.docs;

      final total = docs.length;
      final approved = docs.where((doc) => doc['isApproved'] == true).length;
      final pending = docs
          .where(
              (doc) => doc['isApproved'] == false && doc['isRejected'] == false)
          .length;

      return {
        'total': total,
        'approved': approved,
        'pending': pending,
      };
    } catch (e) {
      throw Exception('فشل جلب إحصائيات النقاط: $e');
    }
  }
}
