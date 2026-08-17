import 'package:cloud_firestore/cloud_firestore.dart';

/// يكتب/يقرأ مواقع السائقين العامة للخريطة وبطاقة المعلومات.
///
/// المجموعة: [driverPublic/{uid}]
class DriverPublicLocationService {
  DriverPublicLocationService._();
  static final DriverPublicLocationService instance =
      DriverPublicLocationService._();
  factory DriverPublicLocationService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String collection = 'driverPublic';

  DocumentReference<Map<String, dynamic>> doc(String uid) =>
      _db.collection(collection).doc(uid);

  Future<void> publishLocation({
    required String uid,
    required double latitude,
    required double longitude,
    required bool isOnline,
    required bool isTripActive,
    double? heading,
    double? speed,
    String? fullName,
    String? busNumber,
    String? route,
    String? routeDetail,
    String? phoneNumber,
    int? capacity,
  }) async {
    if (uid.isEmpty) return;

    if (!isOnline && !isTripActive) {
      await markOffline(uid);
      return;
    }

    final data = <String, dynamic>{
      'currentLatitude': latitude,
      'currentLongitude': longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isOnline': isOnline,
      'isTripActive': isTripActive,
      'isSharingLocation': isOnline,
    };
    if (heading != null) data['heading'] = heading;
    if (speed != null) data['speed'] = speed;
    if (fullName != null && fullName.isNotEmpty) data['fullName'] = fullName;
    if (busNumber != null) data['busNumber'] = busNumber;
    if (route != null) data['route'] = route;
    if (routeDetail != null) data['routeDetail'] = routeDetail;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (capacity != null) data['capacity'] = capacity;

    await doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> publishStatus({
    required String uid,
    required bool isOnline,
    bool? isTripActive,
    double? latitude,
    double? longitude,
    String? fullName,
    String? busNumber,
    String? route,
    String? routeDetail,
    String? phoneNumber,
    int? capacity,
  }) async {
    if (uid.isEmpty) return;

    if (!isOnline) {
      await markOffline(uid);
      return;
    }

    final data = <String, dynamic>{
      'isOnline': true,
      'isSharingLocation': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isTripActive != null) data['isTripActive'] = isTripActive;
    if (latitude != null && longitude != null) {
      data['currentLatitude'] = latitude;
      data['currentLongitude'] = longitude;
      data['locationUpdatedAt'] = FieldValue.serverTimestamp();
    }
    if (fullName != null && fullName.isNotEmpty) data['fullName'] = fullName;
    if (busNumber != null) data['busNumber'] = busNumber;
    if (route != null) data['route'] = route;
    if (routeDetail != null) data['routeDetail'] = routeDetail;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (capacity != null) data['capacity'] = capacity;

    await doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> markOffline(String uid) async {
    if (uid.isEmpty) return;
    await doc(uid).set({
      'isOnline': false,
      'isSharingLocation': false,
      'isTripActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOnline() {
    return _db
        .collection(collection)
        .where('isOnline', isEqualTo: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriver(String uid) {
    return doc(uid).snapshots();
  }
}
