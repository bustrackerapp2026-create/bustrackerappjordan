import 'package:cloud_firestore/cloud_firestore.dart';

/// حالة الرحلة التشغيلية للحافلة (منفصلة عن TripStatus الخاصة بطلبات الركاب).
enum VehicleTripStatus {
  active,
  completed,
  cancelled,
}

extension VehicleTripStatusX on VehicleTripStatus {
  String get firestoreValue {
    switch (this) {
      case VehicleTripStatus.active:
        return 'active';
      case VehicleTripStatus.completed:
        return 'completed';
      case VehicleTripStatus.cancelled:
        return 'cancelled';
    }
  }

  String get labelAr {
    switch (this) {
      case VehicleTripStatus.active:
        return 'نشطة';
      case VehicleTripStatus.completed:
        return 'مكتملة';
      case VehicleTripStatus.cancelled:
        return 'ملغاة';
    }
  }

  bool get isTerminal =>
      this == VehicleTripStatus.completed || this == VehicleTripStatus.cancelled;

  bool get isActive => this == VehicleTripStatus.active;

  static VehicleTripStatus fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'active':
        return VehicleTripStatus.active;
      case 'completed':
        return VehicleTripStatus.completed;
      case 'cancelled':
        return VehicleTripStatus.cancelled;
      default:
        throw FormatException('Unknown VehicleTripStatus: $value');
    }
  }
}

/// رحلة تشغيلية لحافلة واحدة على مسار معتمد (Vehicle Operation).
///
/// منفصلة عن [TripModel] (طلبات الركاب).
class VehicleTrip {
  final String id;
  final String driverId;
  final String busNumber;
  final String routeId;

  /// outbound | return — من PlannedRoute.direction
  final String direction;
  final VehicleTripStatus status;
  final GeoPoint? currentLocation;
  final double? speed;
  final double? heading;
  final double? routeProgress;
  final DateTime? lastLocationAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VehicleTrip({
    required this.id,
    required this.driverId,
    required this.busNumber,
    required this.routeId,
    required this.direction,
    required this.status,
    this.currentLocation,
    this.speed,
    this.heading,
    this.routeProgress,
    this.lastLocationAt,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory VehicleTrip.fromMap(Map<String, dynamic> map, String docId) {
    return VehicleTrip(
      id: docId,
      driverId: map['driverId']?.toString() ?? '',
      busNumber: map['busNumber']?.toString() ?? '',
      routeId: map['routeId']?.toString() ?? '',
      direction: parseDirection(map['direction']?.toString()),
      status: VehicleTripStatusX.fromString(map['status']?.toString()),
      currentLocation: _parseGeoPoint(map['currentLocation']),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      routeProgress: (map['routeProgress'] as num?)?.toDouble(),
      lastLocationAt: _parseTimestamp(map['lastLocationAt']),
      startedAt: _parseTimestamp(map['startedAt']),
      endedAt: _parseTimestamp(map['endedAt']),
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  factory VehicleTrip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VehicleTrip.fromMap(data, doc.id);
  }

  /// خريطة الإنشاء مع server timestamps.
  Map<String, dynamic> toCreateMap() {
    return {
      'driverId': driverId,
      'busNumber': busNumber,
      'routeId': routeId,
      'direction': direction,
      'status': status.firestoreValue,
      if (currentLocation != null) 'currentLocation': currentLocation,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (routeProgress != null) 'routeProgress': routeProgress,
      if (currentLocation != null)
        'lastLocationAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'busNumber': busNumber,
      'routeId': routeId,
      'direction': direction,
      'status': status.firestoreValue,
      if (currentLocation != null) 'currentLocation': currentLocation,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (routeProgress != null) 'routeProgress': routeProgress,
      if (lastLocationAt != null) 'lastLocationAt': Timestamp.fromDate(lastLocationAt!),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  VehicleTrip copyWith({
    String? id,
    String? driverId,
    String? busNumber,
    String? routeId,
    String? direction,
    VehicleTripStatus? status,
    GeoPoint? currentLocation,
    double? speed,
    double? heading,
    double? routeProgress,
    DateTime? lastLocationAt,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleTrip(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      busNumber: busNumber ?? this.busNumber,
      routeId: routeId ?? this.routeId,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      routeProgress: routeProgress ?? this.routeProgress,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String parseDirection(String? value) {
    final v = value?.trim().toLowerCase();
    if (v == 'outbound' || v == 'return') return v!;
    throw FormatException('Unknown VehicleTrip direction: $value');
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static GeoPoint? _parseGeoPoint(dynamic value) {
    if (value == null) return null;
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = (value['latitude'] as num?)?.toDouble();
      final lng = (value['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) return GeoPoint(lat, lng);
    }
    return null;
  }

  @override
  String toString() =>
      'VehicleTrip(id: $id, driverId: $driverId, routeId: $routeId, '
      'direction: $direction, status: ${status.firestoreValue})';
}
