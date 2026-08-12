import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/bus_capacity.dart';

/// موقع سائق متصل يظهر مباشرة على خرائط الركاب/الأدمن.
class LiveDriverLocation {
  final String driverId;
  final String fullName;
  final String? busNumber;
  final String? route;
  /// سعة الباص: 5 سرفيس / 23 متوسط / 50 كبير
  final int? capacity;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final bool isOnline;
  final bool isTripActive;
  final DateTime? updatedAt;

  const LiveDriverLocation({
    required this.driverId,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    this.busNumber,
    this.route,
    this.capacity,
    this.heading,
    this.speed,
    this.isOnline = true,
    this.isTripActive = false,
    this.updatedAt,
  });

  bool get hasValidCoords =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);

  /// هل التحديث حديث؟ (أقل من 15 دقيقة — يسمح ببقاء الظهور بعد إغلاق التطبيق)
  bool get isFresh {
    if (updatedAt == null) return true;
    return DateTime.now().difference(updatedAt!) < const Duration(minutes: 15);
  }

  factory LiveDriverLocation.fromUserDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final lat = (data['currentLatitude'] as num?)?.toDouble() ?? 0;
    final lng = (data['currentLongitude'] as num?)?.toDouble() ?? 0;

    DateTime? updated;
    final raw = data['locationUpdatedAt'] ?? data['lastUpdated'];
    if (raw is Timestamp) updated = raw.toDate();
    if (raw is DateTime) updated = raw;

    return LiveDriverLocation(
      driverId: id,
      fullName: data['fullName']?.toString() ?? 'سائق',
      busNumber: data['busNumber']?.toString(),
      route: data['route']?.toString(),
      capacity: BusCapacity.normalize(data['capacity']),
      latitude: lat,
      longitude: lng,
      heading: (data['heading'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      isOnline: data['isOnline'] == true,
      isTripActive: data['isTripActive'] == true,
      updatedAt: updated,
    );
  }

  String get displayLabel {
    final type = BusCapacity.shortLabel(capacity);
    final bus = busNumber?.trim();
    if (bus != null && bus.isNotEmpty) return '$type $bus';
    return '$type · $fullName';
  }
}
