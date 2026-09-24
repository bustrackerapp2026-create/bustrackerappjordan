import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// حالات حماية الجلسة التشغيلية للمركبة.
/// الجلسة مرتبطة برقم المركبة، بينما تبقى هوية السائق محفوظة للتدقيق.
class VehicleOperationalSessionException implements Exception {
  final String message;
  final String code;

  const VehicleOperationalSessionException(
    this.message, {
    this.code = 'vehicle-session-error',
  });

  @override
  String toString() => message;
}

class VehicleOperationalSessionService {
  VehicleOperationalSessionService._();
  static final VehicleOperationalSessionService instance =
      VehicleOperationalSessionService._();
  factory VehicleOperationalSessionService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// مهلة اعتبار الجلسة قديمة قبل السماح بنقل التشغيل.
  static const Duration staleAfter = Duration(minutes: 15);

  /// حد محافظ لحساب أقصى مسافة ممكنة أثناء الانقطاع.
  static const double maxAssumedSpeedKmh = 80.0;

  /// هامش أمان بسيط فوق المسافة النظرية.
  static const double safetyMarginMeters = 2000.0;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('vehicleOperationalSessions');

  String _docId(String busNumber) => busNumber.trim();

  DateTime? _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _validCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _maxReachableDistanceMeters(Duration elapsed) {
    final hours = elapsed.inMilliseconds / 3600000.0;
    return maxAssumedSpeedKmh * 1000.0 * hours + safetyMarginMeters;
  }

  Map<String, dynamic> _activePayload({
    required String busNumber,
    required String driverId,
    required double latitude,
    required double longitude,
    bool isTripActive = false,
    String tripId = '',
  }) {
    return {
      'busNumber': busNumber,
      'activeDriverId': driverId,
      'status': 'active',
      'isTripActive': isTripActive,
      'tripId': tripId,
      'lastLatitude': latitude,
      'lastLongitude': longitude,
      'lastHeartbeatAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// يحجز/يجدد جلسة المركبة.
  ///
  /// عند وجود سائق آخر:
  /// - لا يسمح بالاستحواذ ما دامت الجلسة حديثة.
  /// - لا يسمح بالاستحواذ إطلاقًا أثناء رحلة نشطة.
  /// - بعد انتهاء المهلة، يجب وجود آخر موقع معروف وحساب مكاني منطقي.
  Future<void> claimOrRefresh({
    required String driverId,
    required String busNumber,
    required double latitude,
    required double longitude,
  }) async {
    final driver = driverId.trim();
    final bus = busNumber.trim();

    if (driver.isEmpty || bus.isEmpty) {
      throw const VehicleOperationalSessionException(
        'بيانات جلسة المركبة غير مكتملة.',
        code: 'invalid-session-data',
      );
    }
    if (!_validCoordinate(latitude, longitude)) {
      throw const VehicleOperationalSessionException(
        'موقع السائق الحالي غير صالح.',
        code: 'invalid-location',
      );
    }

    final ref = _col.doc(_docId(bus));

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);

      if (!snap.exists || snap.data() == null) {
        tx.set(
          ref,
          _activePayload(
            busNumber: bus,
            driverId: driver,
            latitude: latitude,
            longitude: longitude,
          ),
        );
        return;
      }

      final data = snap.data()!;
      final status = data['status']?.toString() ?? 'active';
      final activeDriver =
          data['activeDriverId']?.toString().trim() ?? '';

      if (status != 'active' || activeDriver.isEmpty) {
        tx.set(
          ref,
          _activePayload(
            busNumber: bus,
            driverId: driver,
            latitude: latitude,
            longitude: longitude,
          ),
          SetOptions(merge: true),
        );
        return;
      }

      if (activeDriver == driver) {
        tx.update(
          ref,
          _activePayload(
            busNumber: bus,
            driverId: driver,
            latitude: latitude,
            longitude: longitude,
            isTripActive: data['isTripActive'] == true,
            tripId: data['tripId']?.toString() ?? '',
          ),
        );
        return;
      }

      final existingTripActive = data['isTripActive'] == true;
      final existingTripId = data['tripId']?.toString().trim() ?? '';

      if (existingTripActive || existingTripId.isNotEmpty) {
        throw const VehicleOperationalSessionException(
          'هذه المركبة مستخدمة حاليًا في رحلة نشطة ولا يمكن نقل التشغيل إلى سائق آخر تلقائيًا.',
          code: 'active-trip-exists',
        );
      }

      final lastHeartbeat = _readTimestamp(data['lastHeartbeatAt']);
      if (lastHeartbeat == null) {
        throw const VehicleOperationalSessionException(
          'تعذر التحقق من آخر حالة للمركبة. يجب مراجعة الأدمن قبل نقل التشغيل.',
          code: 'handover-requires-admin',
        );
      }

      final elapsed = DateTime.now().difference(lastHeartbeat);
      if (elapsed < staleAfter) {
        final remaining = staleAfter - elapsed;
        final minutes = remaining.inMinutes +
            (remaining.inSeconds % 60 == 0 ? 0 : 1);

        throw VehicleOperationalSessionException(
          'المركبة مرتبطة حاليًا بسائق آخر. توجد مهلة حماية متبقية قدرها ' +
              minutes.toString() +
              ' دقيقة قبل السماح بنقل التشغيل.',
          code: 'vehicle-busy',
        );
      }

      final oldLat = _readDouble(data['lastLatitude']);
      final oldLon = _readDouble(data['lastLongitude']);

      if (!_validCoordinate(oldLat, oldLon)) {
        throw const VehicleOperationalSessionException(
          'انتهت جلسة السائق السابق لكن لا يوجد آخر موقع موثوق للمركبة. يجب مراجعة الأدمن قبل نقل التشغيل.',
          code: 'handover-requires-admin',
        );
      }

      final distance =
          _distanceMeters(oldLat!, oldLon!, latitude, longitude);
      final maxReachable = _maxReachableDistanceMeters(elapsed);

      if (distance > maxReachable) {
        throw const VehicleOperationalSessionException(
          'لا يمكن نقل تشغيل المركبة: موقع السائق الجديد لا يتوافق مع المسافة التي يمكن للمركبة قطعها خلال مدة الانقطاع.',
          code: 'location-mismatch',
        );
      }

      tx.set(
        ref,
        {
          ..._activePayload(
            busNumber: bus,
            driverId: driver,
            latitude: latitude,
            longitude: longitude,
          ),
          'previousDriverId': activeDriver,
          'handedOverAt': FieldValue.serverTimestamp(),
          'handoverReason': 'stale-session-and-location-check',
        },
      );
    });
  }

  /// نبضة تشغيل للمركبة أثناء الاتصال/الرحلة.
  /// ترجع false إذا فقد السائق ملكية الجلسة بسبب استلام سائق آخر.
  Future<bool> heartbeat({
    required String driverId,
    required String busNumber,
    required double latitude,
    required double longitude,
    bool isTripActive = false,
  }) async {
    final driver = driverId.trim();
    final bus = busNumber.trim();

    if (driver.isEmpty ||
        bus.isEmpty ||
        !_validCoordinate(latitude, longitude)) {
      return false;
    }

    final ref = _col.doc(_docId(bus));
    var owned = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists || snap.data() == null) return;

      final data = snap.data()!;
      if (data['status']?.toString() != 'active' ||
          data['activeDriverId']?.toString().trim() != driver) {
        return;
      }

      final update = <String, dynamic>{
        'lastLatitude': latitude,
        'lastLongitude': longitude,
        'lastHeartbeatAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isTripActive) {
        update['isTripActive'] = true;
      }

      tx.update(ref, update);
      owned = true;
    });

    return owned;
  }

  /// تحديث حالة الرحلة داخل جلسة المركبة.
  Future<bool> setTripActive({
    required String driverId,
    required String busNumber,
    required bool isTripActive,
    String tripId = '',
  }) async {
    final driver = driverId.trim();
    final bus = busNumber.trim();
    if (driver.isEmpty || bus.isEmpty) return false;

    final ref = _col.doc(_docId(bus));
    var owned = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists || snap.data() == null) return;

      final data = snap.data()!;
      if (data['status']?.toString() != 'active' ||
          data['activeDriverId']?.toString().trim() != driver) {
        return;
      }

      tx.update(ref, {
        'isTripActive': isTripActive,
        'tripId': isTripActive ? tripId.trim() : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      owned = true;
    });

    return owned;
  }

  /// يحرر المركبة فقط للسائق المالك للجلسة، ولا يحررها أثناء رحلة نشطة.
  Future<void> release({
    required String driverId,
    required String busNumber,
  }) async {
    final driver = driverId.trim();
    final bus = busNumber.trim();
    if (driver.isEmpty || bus.isEmpty) return;

    final ref = _col.doc(_docId(bus));

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists || snap.data() == null) return;

      final data = snap.data()!;
      if (data['activeDriverId']?.toString().trim() != driver) return;

      if (data['isTripActive'] == true ||
          data['tripId']?.toString().trim().isNotEmpty == true) {
        throw const VehicleOperationalSessionException(
          'لا يمكن تحرير المركبة أثناء وجود رحلة نشطة. أنهِ الرحلة أولًا.',
          code: 'active-trip-exists',
        );
      }

      tx.update(ref, {
        'status': 'released',
        'releasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
