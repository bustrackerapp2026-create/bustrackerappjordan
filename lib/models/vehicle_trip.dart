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
/// لا علاقة لها بطلبات الركاب (Passenger Trip).
/// المصدر التشغيلي للحقيقة: vehicleTrips/{id}
class VehicleTrip {
  final String id;
  final String driverId;

  /// لقطة رقم الحافلة وقت بدء الرحلة (لا يتغير لاحقًا).
  final String busNumber;

  /// معرف PlannedRoute المعتمد.
  final String routeId;

  /// outbound | return — من PlannedRoute.direction
  final String direction;

  final VehicleTripStatus status;

  final GeoPoint? currentLocation;
  final double? speed;
  final double? heading;

  /// نسبة التقدم على المسار 0.0 → 1.0 (محسوبة لاحقًا، ليست من العميل).
  final double? routeProgress;

  /// آخر وقت استُقبل فيه GPS صالح.
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
    this.status = VehicleTripStatus.active,
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

  bool get isActive => status.isActive;
  bool get isTerminal => status.isTerminal;

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
      lastLocationAt: _parseOptionalDate(map['lastLocationAt']),
      startedAt: _parseOptionalDate(map['startedAt']),
      endedAt: _parseOptionalDate(map['endedAt']),
      createdAt: _parseOptionalDate(map['createdAt']),
      updatedAt: _parseOptionalDate(map['updatedAt']),
    );
  }

  factory VehicleTrip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VehicleTrip.fromMap(data, doc.id);
  }

  /// خريطة الإنشاء — تستخدم server timestamps للحقول الزمنية الحساسة.
  Map<String, dynamic> toCreateMap() {
    return {
      'driverId': driverId,
      'busNumber': busNumber,
      'routeId': routeId,
      'direction': direction,
      'status': VehicleTripStatus.active.firestoreValue,
      if (currentLocation != null) 'currentLocation': currentLocation,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      'routeProgress': null,
      if (currentLocation != null)
        'lastLocationAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
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
      if (lastLocationAt != null)
        'lastLocationAt': Timestamp.fromDate(lastLocationAt!),
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
    switch (value?.trim().toLowerCase()) {
      case 'outbound':
        return 'outbound';
      case 'return':
        return 'return';
      default:
        throw FormatException('Unknown VehicleTrip direction: $value');
    }
  }

  static GeoPoint? _parseGeoPoint(dynamic value) {
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = (value['latitude'] as num?)?.toDouble();
      final lng = (value['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) return GeoPoint(lat, lng);
    }
    return null;
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  String toString() =>
      'VehicleTrip(id: $id, driverId: $driverId, routeId: $routeId, '
      'direction: $direction, status: ${status.firestoreValue})';
}
