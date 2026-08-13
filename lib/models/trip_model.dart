import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_status.dart';
import 'route_point.dart';

/// نموذج بيانات الرحلة مع تحليل دفاعي وحماية البيانات
class TripModel {
  final String id;
  final String passengerId;
  final String driverId;
  final String pickupPoint;
  final String dropoffPoint;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final TripStatus status;
  final double? fare;
  final String? notes;
  final List<RoutePoint>? routePoints;

  static const int _maxPickupLength = 100;
  static const int _maxDropoffLength = 100;
  static const int _maxNotesLength = 500;
  static const int _maxRoutePoints = 5000;

  TripModel({
    required this.id,
    required this.passengerId,
    required this.driverId,
    required String pickupPoint,
    required String dropoffPoint,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.status = TripStatus.pending,
    this.fare,
    String? notes,
    List<RoutePoint>? routePoints,
  })  : pickupPoint =
            _validateStringLength(pickupPoint, 'pickupPoint', _maxPickupLength),
        dropoffPoint = _validateStringLength(
            dropoffPoint, 'dropoffPoint', _maxDropoffLength),
        notes = notes != null
            ? _validateStringLength(notes, 'notes', _maxNotesLength)
            : null,
        routePoints = _validateRoutePoints(routePoints);

  static String _validateStringLength(
      String value, String fieldName, int maxLength) {
    if (value.length > maxLength) {
      throw ArgumentError('حقل $fieldName يتجاوز الحد الأقصى ($maxLength حرف). '
          'الطول الحالي: ${value.length} حرف.');
    }
    return value;
  }

  static List<RoutePoint>? _validateRoutePoints(List<RoutePoint>? points) {
    if (points == null) return null;
    if (points.length > _maxRoutePoints) {
      throw ArgumentError(
          'عدد نقاط المسار يتجاوز الحد الأقصى ($_maxRoutePoints نقطة). '
          'العدد الحالي: ${points.length} نقطة.');
    }
    return points;
  }

  static DateTime _parseRequiredDate(dynamic value, String fieldName) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw FormatException('تاريخ غير صالح أو مفقود للحقل $fieldName');
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  factory TripModel.fromMap(Map<String, dynamic> map, String docId) {
    try {
      List<RoutePoint>? parsedRoute;
      if (map['routePoints'] is List) {
        parsedRoute = (map['routePoints'] as List)
            .map((item) {
              try {
                return RoutePoint.parse(item);
              } catch (_) {
                return null;
              }
            })
            .whereType<RoutePoint>()
            .toList();
        if (parsedRoute.length > _maxRoutePoints) {
          parsedRoute = parsedRoute.sublist(0, _maxRoutePoints);
        }
      }

      String clip(String? v, int max) {
        final s = (v ?? '').trim();
        if (s.length <= max) return s;
        return s.substring(0, max);
      }

      DateTime created;
      try {
        created = _parseRequiredDate(map['createdAt'], 'createdAt');
      } catch (_) {
        created = DateTime.now();
      }

      return TripModel(
        id: docId,
        passengerId: map['passengerId'] as String? ?? '',
        driverId: map['driverId'] as String? ?? '',
        pickupPoint: clip(map['pickupPoint'] as String?, _maxPickupLength),
        dropoffPoint: clip(map['dropoffPoint'] as String?, _maxDropoffLength),
        createdAt: created,
        startedAt: _parseOptionalDate(map['startedAt']),
        completedAt: _parseOptionalDate(map['completedAt']),
        status: TripStatusExtension.fromString(
            map['status'] as String? ?? 'pending'),
        fare: (map['fare'] as num?)?.toDouble(),
        notes: map['notes'] == null
            ? null
            : clip(map['notes'] as String?, _maxNotesLength),
        routePoints: parsedRoute,
      );
    } catch (e) {
      return TripModel(
        id: docId,
        passengerId: map['passengerId'] as String? ?? '',
        driverId: map['driverId'] as String? ?? '',
        pickupPoint: (map['pickupPoint'] as String? ?? '').length > 100
            ? (map['pickupPoint'] as String).substring(0, 100)
            : (map['pickupPoint'] as String? ?? ''),
        dropoffPoint: (map['dropoffPoint'] as String? ?? '').length > 100
            ? (map['dropoffPoint'] as String).substring(0, 100)
            : (map['dropoffPoint'] as String? ?? ''),
        createdAt: DateTime.now(),
        status: TripStatus.pending,
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'driverId': driverId,
      'pickupPoint': pickupPoint,
      'dropoffPoint': dropoffPoint,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'status': status.stringValue,
      'fare': fare,
      'notes': notes,
      if (routePoints != null && routePoints!.isNotEmpty)
        'routePoints': routePoints!.map((p) => p.toMap()).toList(),
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }

  TripModel copyWith({
    String? id,
    String? passengerId,
    String? driverId,
    String? pickupPoint,
    String? dropoffPoint,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    TripStatus? status,
    double? fare,
    String? notes,
    List<RoutePoint>? routePoints,
  }) {
    final newPickupPoint = pickupPoint != null
        ? _validateStringLength(pickupPoint, 'pickupPoint', _maxPickupLength)
        : this.pickupPoint;
    final newDropoffPoint = dropoffPoint != null
        ? _validateStringLength(dropoffPoint, 'dropoffPoint', _maxDropoffLength)
        : this.dropoffPoint;
    final newNotes = notes != null
        ? _validateStringLength(notes, 'notes', _maxNotesLength)
        : this.notes;
    final newRoutePoints = routePoints != null
        ? _validateRoutePoints(routePoints)
        : this.routePoints;

    return TripModel(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      pickupPoint: newPickupPoint,
      dropoffPoint: newDropoffPoint,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      notes: newNotes,
      routePoints: newRoutePoints,
    );
  }
}
