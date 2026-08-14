import 'package:cloud_firestore/cloud_firestore.dart';

/// يكتب/يقرأ مواقع السائقين العامة بدون كشف بريد/هاتف/حقول حساسة.
///
/// المجموعة: [driverPublic/{uid}]
/// الحقول المسموحة فقط: اسم العرض، باص، مسار، سعة، إحداثيات، حالة اتصال/رحلة.
class DriverPublicLocationService {
  DriverPublicLocationService._();
  static final DriverPublicLocationService instance =
      DriverPublicLocationService._();
  factory DriverPublicLocationService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String collection = 'driverPublic';

  DocumentReference<Map<String, dynamic>> doc(String uid) =>
      _db.collection(collection).doc(uid);

  /// دمج حقول عامة فقط (merge) — آمن للاستدعاء المتكرر من التتبع.
  Future<void> upsert({
    required String uid,
    String? fullName,
    String? busNumber,
    String? route,
    int? capacity,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    bool? isOnline,
    bool? isTripActive,
  }) async {
    if (uid.isEmpty) return;

    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (fullName != null) data['fullName'] = fullName;
    if (busNumber != null) data['busNumber'] = busNumber;
    if (route != null) data['route'] = route;
    if (capacity != null) data['capacity'] = capacity;
    if (isOnline != null) data['isOnline'] = isOnline;
    if (isTripActive != null) data['isTripActive'] = isTripActive;
    if (heading != null) data['heading'] = heading;
    if (speed != null) data['speed'] = speed;

    if (latitude != null && longitude != null) {
      data['currentLatitude'] = latitude;
      data['currentLongitude'] = longitude;
      data['locationUpdatedAt'] = FieldValue.serverTimestamp();
    }

    if (!isOnline! && isOnline == false) {
      // handled below
    }

    if (isOnline == false) {
      data['isOnline'] = false;
      data['isSharingLocation'] = false;
      data['isTripActive'] = false;
    }

    await doc(uid).set(data, SetOptions(merge: true));
  }

  /// تحديث موقع فقط + حالة اتصال (مسار التتبع المستمر).
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
    if (fullName != null) data['fullName'] = fullName;
    if (busNumber != null) data['busNumber'] = busNumber;
    if (route != null) data['route'] = route;
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
