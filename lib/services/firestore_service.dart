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

  // ✅ دالة للحصول على إحصائيات السائقين (محسنة وآمنة)
  Future<Map<String, int>> getDriversStats() async {
    try {
      final allDrivers = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'driver')
          .get();

      int verified = 0;
      int pending = 0;
      int rejected = 0;

      for (var doc in allDrivers.docs) {
        final data = doc.data();
        final isVerified = data['isVerified'] == true;
        final isRejected = data['isRejected'] == true;

        if (isVerified) {
          verified++;
        } else if (isRejected) {
          rejected++;
        } else {
          pending++;
        }
      }

      return {
        'total': allDrivers.docs.length,
        'verified': verified,
        'pending': pending,
        'rejected': rejected,
      };
    } catch (e) {
      throw Exception('فشل جلب إحصائيات السائقين: $e');
    }
  }

  // ✅ دالة لجلب جميع إحصائيات المستخدمين والأنشطة حقيقياً (سريعة وآمنة جداً)
  Future<Map<String, int>> getAllUsersStats() async {
    try {
      final allUsers = await _firestore.collection('users').get();
      final docs = allUsers.docs;

      int total = docs.length;
      int passenger = 0;
      int driver = 0;
      int service = 0;
      int busCompany = 0;

      int verified = 0;
      int pending = 0;
      int rejected = 0;

      int activeBuses = 0;
      int activePassengers = 0;
      int activeServices = 0;
      int activeOthers = 0;

      // دورة واحدة سريعة جداً لحساب كل الإحصائيات مع الحماية من القيم الفارغة
      for (var doc in docs) {
        final data = doc.data();
        final userType = data['userType']?.toString() ?? '';

        // 1️⃣ إحصائيات حسب نوع المستخدم
        if (userType == 'passenger') {
          passenger++;
        } else if (userType == 'driver') {
          driver++;
        } else if (userType == 'service') {
          service++;
        } else if (userType == 'bus_company') {
          busCompany++;
        }

        // 2️⃣ إحصائيات حالة التوثيق للسائقين
        if (userType == 'driver') {
          final isVerified = data['isVerified'] == true;
          final isRejected = data['isRejected'] == true;

          if (isVerified) {
            verified++;
          } else if (isRejected) {
            rejected++;
          } else {
            pending++;
          }
        }

        // 3️⃣ حساب المستخدمين النشطين حقيقياً (بناء على حالة الاتصال/النشاط)
        final isOnline = data['isOnline'] == true ||
            data['isActive'] == true ||
            data['status'] == 'active';

        if (isOnline) {
          if (userType == 'driver') {
            activeBuses++;
          } else if (userType == 'passenger') {
            activePassengers++;
          } else if (userType == 'service') {
            activeServices++;
          } else {
            activeOthers++;
          }
        }
      }

      return {
        'total': total,
        'passenger': passenger,
        'driver': driver,
        'service': service,
        'bus_company': busCompany,
        'verified': verified,
        'pending': pending,
        'rejected': rejected,
        'active_buses': activeBuses,
        'active_passengers': activePassengers,
        'active_services': activeServices,
        'active_others': activeOthers,
      };
    } catch (e) {
      throw Exception('فشل جلب إحصائيات المستخدمين: $e');
    }
  }

  // ✅ دالة لجلب المستخدمين النشطين فقط حقيقياً
  Future<Map<String, int>> getActiveUsersStats() async {
    try {
      final stats = await getAllUsersStats();
      return {
        'buses': stats['active_buses'] ?? 0,
        'passengers': stats['active_passengers'] ?? 0,
        'services': stats['active_services'] ?? 0,
        'others': stats['active_others'] ?? 0,
      };
    } catch (e) {
      throw Exception('فشل جلب إحصائيات النشطين: $e');
    }
  }

  // ✅ دالة لجلب إحصائيات النقاط (آمنة وحقيقية)
  Future<Map<String, int>> getPickupPointsStats() async {
    try {
      final allPoints = await _firestore.collection('pickupPoints').get();
      final docs = allPoints.docs;

      int total = docs.length;
      int approved = 0;
      int pending = 0;

      for (var doc in docs) {
        final data = doc.data();
        final isApproved = data['isApproved'] == true;
        final isRejected = data['isRejected'] == true;

        if (isApproved) {
          approved++;
        } else if (!isRejected) {
          pending++;
        }
      }

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
