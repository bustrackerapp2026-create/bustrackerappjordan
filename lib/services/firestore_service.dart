import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
      try {
        if (snapshot.exists && snapshot.data() != null) {
          return UserModel.fromMap(snapshot.data()!, snapshot.id);
        }
      } catch (e) {
        debugPrint('getUserDataStream parse error: $e');
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

  Future<void> approveDriver(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isVerified': true,
        'isRejected': false,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل الموافقة على السائق: $e');
    }
  }

  Future<void> rejectDriver(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isVerified': false,
        'isRejected': true,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل رفض السائق: $e');
    }
  }

  Future<void> resetDriverVerification(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isVerified': false,
        'isRejected': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('فشل إعادة الطلب للانتظار: $e');
    }
  }

  static String _str(Map<String, dynamic> data, String key, [String def = '']) {
    final v = data[key];
    if (v == null) return def;
    return v.toString().trim();
  }

  static bool _boolTrue(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  static bool _isDriverLike(String type) {
    return type == 'driver' || type == 'service' || type == 'bus_company';
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snap = await query.count().get();
    return snap.count ?? 0;
  }

  /// بث بعدد المعلقين — استعلام مفلتر بدل مسح كل users.
  Stream<int> watchPendingDriverApprovals() {
    return _firestore
        .collection('users')
        .where('userType', whereIn: ['driver', 'service', 'bus_company'])
        .where('isVerified', isEqualTo: false)
        .snapshots()
        .map((snap) {
      var pending = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (_boolTrue(data, 'isRejected')) continue;
        pending++;
      }
      return pending;
    }).handleError((e) {
      debugPrint('watchPendingDriverApprovals: $e');
      return 0;
    });
  }

  Map<String, int> _emptyUsersStats() {
    return {
      'total': 0,
      'admin': 0,
      'passenger': 0,
      'driver': 0,
      'service': 0,
      'bus_company': 0,
      'verified': 0,
      'pending': 0,
      'rejected': 0,
      'active_buses': 0,
      'active_passengers': 0,
      'active_services': 0,
      'active_others': 0,
    };
  }

  Map<String, int> _emptyPickupStats() {
    return {
      'total': 0,
      'approved': 0,
      'pending': 0,
      'rejected': 0,
    };
  }

  /// إحصاءات السائقين عبر count() مجمّعة.
  Future<Map<String, int>> getDriversStats({bool useFallback = true}) async {
    try {
      final users = _firestore.collection('users');
      final results = await Future.wait([
        _count(users.where('userType', isEqualTo: 'driver')),
        _count(users
            .where('userType', isEqualTo: 'driver')
            .where('isVerified', isEqualTo: true)),
        _count(users
            .where('userType', isEqualTo: 'driver')
            .where('isRejected', isEqualTo: true)),
      ]);

      final total = results[0];
      final verified = results[1];
      final rejected = results[2];
      final pending = (total - verified - rejected).clamp(0, total);

      return {
        'total': total,
        'verified': verified,
        'pending': pending,
        'rejected': rejected,
      };
    } catch (e) {
      if (useFallback) {
        return {'total': 0, 'verified': 0, 'pending': 0, 'rejected': 0};
      }
      throw Exception('فشل جلب الإحصائيات: $e');
    }
  }

  /// إحصاءات المستخدمين عبر count() — بدون جلب كل المستندات.
  Future<Map<String, int>> getAllUsersStats({bool useFallback = true}) async {
    try {
      final users = _firestore.collection('users');
      final public = _firestore.collection('driverPublic');

      final counts = await Future.wait([
        _count(users),
        _count(users.where('userType', isEqualTo: 'admin')),
        _count(users.where('userType', isEqualTo: 'passenger')),
        _count(users.where('userType', isEqualTo: 'driver')),
        _count(users.where('userType', isEqualTo: 'service')),
        _count(users.where('userType', isEqualTo: 'bus_company')),
        // موثّقون من أنواع السائقين
        _count(users
            .where('userType', whereIn: ['driver', 'service', 'bus_company'])
            .where('isVerified', isEqualTo: true)),
        _count(users
            .where('userType', whereIn: ['driver', 'service', 'bus_company'])
            .where('isRejected', isEqualTo: true)),
        // متصلون من المجموعة العامة (أرخص وأكثر دقة للخريطة)
        _count(public.where('isOnline', isEqualTo: true)),
        _count(users
            .where('userType', isEqualTo: 'passenger')
            .where('isOnline', isEqualTo: true)),
        _count(users
            .where('userType', isEqualTo: 'service')
            .where('isOnline', isEqualTo: true)),
      ]);

      final total = counts[0];
      final admin = counts[1];
      final passenger = counts[2];
      final driver = counts[3];
      final service = counts[4];
      final busCompany = counts[5];
      final verified = counts[6];
      final rejected = counts[7];
      final activeBuses = counts[8];
      final activePassengers = counts[9];
      final activeServices = counts[10];

      final driverLike = driver + service + busCompany;
      final pending =
          (driverLike - verified - rejected).clamp(0, driverLike);

      return {
        'total': total,
        'admin': admin,
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
        'active_others': 0,
      };
    } catch (e) {
      if (useFallback) {
        return _emptyUsersStats();
      }
      throw Exception('فشل جلب إحصائيات المستخدمين: $e');
    }
  }

  /// إحصاءات نقاط التجمع عبر count() حسب status.
  Future<Map<String, int>> getPickupPointsStats(
      {bool useFallback = true}) async {
    try {
      final points = _firestore.collection('pickupPoints');
      final results = await Future.wait([
        _count(points),
        _count(points.where('status', isEqualTo: 'approved')),
        _count(points.where('status', isEqualTo: 'pending')),
        _count(points.where('status', isEqualTo: 'rejected')),
      ]);

      return {
        'total': results[0],
        'approved': results[1],
        'pending': results[2],
        'rejected': results[3],
      };
    } catch (e) {
      if (useFallback) {
        return _emptyPickupStats();
      }
      throw Exception('فشل جلب إحصائيات النقاط: $e');
    }
  }

  Future<int> getActiveRoutesCount({bool useFallback = true}) async {
    try {
      return await _count(
        _firestore.collection('routes').where('isActive', isEqualTo: true),
      );
    } catch (e) {
      if (useFallback) return 0;
      throw Exception('فشل جلب عدد المسارات: $e');
    }
  }
}
