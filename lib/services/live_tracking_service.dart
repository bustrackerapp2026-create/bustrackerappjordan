import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_driver_location.dart';

/// خدمة التتبع الحي: بث مواقع السائقين المتصلين من Firestore.
/// كل تحديث يُكتب على users/{uid} فقط — لا يوجد حالة مشتركة بين السائقين.
class LiveTrackingService {
  LiveTrackingService._();
  static final LiveTrackingService instance = LiveTrackingService._();
  factory LiveTrackingService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// سائقون متصلون بموقع صالح (للخريطة الحية) — كل وثيقة = سائق واحد.
  Stream<List<LiveDriverLocation>> watchOnlineDrivers({String? routeFilter}) {
    Query<Map<String, dynamic>> q = _db
        .collection('users')
        .where('userType', isEqualTo: 'driver')
        .where('isOnline', isEqualTo: true);

    return q.snapshots().map((snap) {
      final list = <LiveDriverLocation>[];
      for (final doc in snap.docs) {
        final live = LiveDriverLocation.fromUserDoc(doc.id, doc.data());
        if (!live.hasValidCoords) continue;
        // نظهر السائق المتصل حتى لو تأخر تحديث الموقع قليلاً
        // (مثلاً بعد إغلاق التطبيق مع بقاء isOnline=true)
        if (!live.isFresh && !live.isOnline) continue;
        if (routeFilter != null &&
            routeFilter.isNotEmpty &&
            live.route != null &&
            live.route!.isNotEmpty &&
            live.route != routeFilter) {
          continue;
        }
        list.add(live);
      }
      return list;
    });
  }

  /// بث موقع سائق واحد.
  Stream<LiveDriverLocation?> watchDriver(String driverId) {
    return _db.collection('users').doc(driverId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final live = LiveDriverLocation.fromUserDoc(doc.id, doc.data()!);
      if (!live.hasValidCoords) return null;
      return live;
    });
  }

  /// تحديث حالة الاتصال + مشاركة الموقع لسائق واحد فقط (users/{uid}).
  /// يُستدعى فقط من أزرار شاشة السائق — ليس عند تسجيل الخروج.
  Future<void> setDriverOnlineStatus({
    required String uid,
    required bool isOnline,
    double? latitude,
    double? longitude,
    String? route,
    bool? isTripActive,
  }) async {
    if (uid.isEmpty) {
      throw ArgumentError('uid مطلوب لتحديث حالة السائق');
    }

    final data = <String, dynamic>{
      'isOnline': isOnline,
      'isSharingLocation': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isTripActive != null) {
      data['isTripActive'] = isTripActive;
    }

    // عند إيقاف التوصيل يدوياً من الشاشة نُنهي الرحلة أيضاً لهذا السائق فقط
    if (!isOnline) {
      data['isSharingLocation'] = false;
      data['isTripActive'] = false;
    }

    if (latitude != null && longitude != null) {
      data['currentLatitude'] = latitude;
      data['currentLongitude'] = longitude;
      data['locationUpdatedAt'] = FieldValue.serverTimestamp();
    }
    if (route != null && route.isNotEmpty) {
      data['route'] = route;
    }

    await _db.collection('users').doc(uid).update(data);
  }

  /// تحديث حالة الرحلة لسائق واحد فقط — من شاشة السائق فقط.
  Future<void> setDriverTripActive({
    required String uid,
    required bool isTripActive,
  }) async {
    if (uid.isEmpty) {
      throw ArgumentError('uid مطلوب');
    }
    await _db.collection('users').doc(uid).update({
      'isTripActive': isTripActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
