import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_driver_location.dart';

/// خدمة التتبع الحي: بث مواقع السائقين المتصلين من Firestore.
class LiveTrackingService {
  LiveTrackingService._();
  static final LiveTrackingService instance = LiveTrackingService._();
  factory LiveTrackingService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// سائقون متصلون بموقع صالح (للخريطة الحية).
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
        if (!live.isFresh) continue;
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

  /// بث موقع سائق واحد (مفيد أثناء رحلة نشطة).
  Stream<LiveDriverLocation?> watchDriver(String driverId) {
    return _db.collection('users').doc(driverId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final live = LiveDriverLocation.fromUserDoc(doc.id, doc.data()!);
      if (!live.hasValidCoords) return null;
      return live;
    });
  }

  /// تحديث حالة الاتصال + مشاركة الموقع (+ الخط اختياري).
  Future<void> setDriverOnlineStatus({
    required String uid,
    required bool isOnline,
    double? latitude,
    double? longitude,
    String? route,
  }) async {
    final data = <String, dynamic>{
      'isOnline': isOnline,
      'isSharingLocation': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (latitude != null && longitude != null) {
      data['currentLatitude'] = latitude;
      data['currentLongitude'] = longitude;
      data['locationUpdatedAt'] = FieldValue.serverTimestamp();
    }
    if (route != null && route.isNotEmpty) {
      data['route'] = route;
    }
    if (!isOnline) {
      data['isSharingLocation'] = false;
    }
    await _db.collection('users').doc(uid).update(data);
  }
}
