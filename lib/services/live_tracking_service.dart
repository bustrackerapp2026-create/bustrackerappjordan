import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_driver_location.dart';
import 'analytics_service.dart';
import 'driver_public_location_service.dart';

/// خدمة التتبع الحي: بث مواقع السائقين من [driverPublic] فقط.
/// لا تقرأ مجموعة users للعامة — حماية البريد/الهاتف والحقول الحساسة.
class LiveTrackingService {
  LiveTrackingService._();
  static final LiveTrackingService instance = LiveTrackingService._();
  factory LiveTrackingService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DriverPublicLocationService _public = DriverPublicLocationService();

  Stream<List<LiveDriverLocation>> watchOnlineDrivers({String? routeFilter}) {
    return _public.watchOnline().map((snap) {
      final list = <LiveDriverLocation>[];
      for (final doc in snap.docs) {
        final live = LiveDriverLocation.fromPublicDoc(doc.id, doc.data());
        if (!live.hasValidCoords) continue;
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

  Stream<LiveDriverLocation?> watchDriver(String driverId) {
    return _public.watchDriver(driverId).map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final live = LiveDriverLocation.fromPublicDoc(doc.id, doc.data()!);
      if (!live.hasValidCoords) return null;
      return live;
    });
  }

  Future<void> setDriverOnlineStatus({
    required String uid,
    required bool isOnline,
    double? latitude,
    double? longitude,
    String? route,
    bool? isTripActive,
    String? fullName,
    String? busNumber,
    int? capacity,
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

    // ملف المستخدم الخاص (المالك فقط يقرأه الآخرون عبر القواعد الجديدة)
    await _db.collection('users').doc(uid).update(data);

    // النسخة العامة للخريطة
    await _public.publishStatus(
      uid: uid,
      isOnline: isOnline,
      isTripActive: isTripActive,
      latitude: latitude,
      longitude: longitude,
      fullName: fullName,
      busNumber: busNumber,
      route: route,
      capacity: capacity,
    );

    if (isOnline) {
      AnalyticsService().goOnline();
    } else {
      AnalyticsService().goOffline();
    }
  }

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

    await _public.publishStatus(
      uid: uid,
      isOnline: true,
      isTripActive: isTripActive,
    );

    if (isTripActive) {
      AnalyticsService().startTrip();
    } else {
      AnalyticsService().endTrip();
    }
  }
}
