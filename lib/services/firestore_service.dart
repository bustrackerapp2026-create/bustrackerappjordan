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

  Future<Map<String, int>> getDriversStats({bool useFallback = true}) async {
    try {
      final allDrivers = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'driver')
          .get();

      var verified = 0;
      var pending = 0;
      var rejected = 0;

      for (final doc in allDrivers.docs) {
        final data = doc.data();
        final isVerified = _boolTrue(data, 'isVerified');
        final isRejected = _boolTrue(data, 'isRejected');
        if (isRejected) {
          rejected++;
        } else if (isVerified) {
          verified++;
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
      if (useFallback) {
        return {'total': 0, 'verified': 0, 'pending': 0, 'rejected': 0};
      }
      throw Exception('فشل جلب الإحصائيات: $e');
    }
  }

  Future<Map<String, int>> getAllUsersStats({bool useFallback = true}) async {
    try {
      final allUsers = await _firestore.collection('users').get();

      var total = 0;
      var admin = 0;
      var passenger = 0;
      var driver = 0;
      var service = 0;
      var busCompany = 0;
      var verified = 0;
      var pending = 0;
      var rejected = 0;
      var activeBuses = 0;
      var activePassengers = 0;
      var activeServices = 0;
      var activeOthers = 0;

      for (final doc in allUsers.docs) {
        final data = doc.data();
        total++;

        final type = _str(data, 'userType', 'passenger').toLowerCase();
        switch (type) {
          case 'admin':
            admin++;
            break;
          case 'passenger':
            passenger++;
            break;
          case 'driver':
            driver++;
            break;
          case 'service':
            service++;
            break;
          case 'bus_company':
            busCompany++;
            break;
        }

        if (type == 'driver' || type == 'service' || type == 'bus_company') {
          final isVerified = _boolTrue(data, 'isVerified');
          final isRejected = _boolTrue(data, 'isRejected');
          if (isRejected) {
            rejected++;
          } else if (isVerified) {
            verified++;
          } else {
            pending++;
          }
        }

        final isOnline = _boolTrue(data, 'isOnline');
        if (isOnline) {
          if (type == 'driver') {
            activeBuses++;
          } else if (type == 'passenger') {
            activePassengers++;
          } else if (type == 'service') {
            activeServices++;
          } else if (type != 'admin') {
            activeOthers++;
          }
        }
      }

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
        'active_others': activeOthers,
      };
    } catch (e) {
      if (useFallback) {
        return {
          ..._emptyUsersStats(),
          'active_buses': 0,
          'active_passengers': 0,
          'active_services': 0,
          'active_others': 0,
        };
      }
      throw Exception('فشل جلب إحصائيات المستخدمين: $e');
    }
  }

  Future<Map<String, int>> getPickupPointsStats(
      {bool useFallback = true}) async {
    try {
      final allPoints = await _firestore.collection('pickupPoints').get();

      var total = 0;
      var approved = 0;
      var pending = 0;
      var rejected = 0;

      for (final doc in allPoints.docs) {
        final data = doc.data();
        total++;

        final status = _str(data, 'status', '').toLowerCase();

        if (status == 'approved') {
          approved++;
        } else if (status == 'rejected') {
          rejected++;
        } else if (status == 'pending' || status.isEmpty) {
          if (_boolTrue(data, 'isRejected')) {
            rejected++;
          } else if (_boolTrue(data, 'isApproved')) {
            approved++;
          } else {
            pending++;
          }
        } else {
          pending++;
        }
      }

      return {
        'total': total,
        'approved': approved,
        'pending': pending,
        'rejected': rejected,
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
      final snap = await _firestore
          .collection('routes')
          .where('isActive', isEqualTo: true)
          .get();
      return snap.docs.length;
    } catch (e) {
      if (useFallback) return 0;
      throw Exception('فشل جلب عدد المسارات: $e');
    }
  }
}
