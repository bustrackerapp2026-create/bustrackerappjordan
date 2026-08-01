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

  // ✅ حدود الأحرف المسموحة
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
  })  :
        // ✅ تطبيق التحقق من صحة المدخلات
        pickupPoint =
            _validateStringLength(pickupPoint, 'pickupPoint', _maxPickupLength),
        dropoffPoint = _validateStringLength(
            dropoffPoint, 'dropoffPoint', _maxDropoffLength),
        notes = notes != null
            ? _validateStringLength(notes, 'notes', _maxNotesLength)
            : null,
        routePoints = _validateRoutePoints(routePoints) {
    // ✅ التحقق الإضافي: إذا كانت الرحلة مكتملة، يجب أن يكون هناك مسار
    if (status == TripStatus.completed &&
        (routePoints == null || routePoints.isEmpty)) {
      throw ArgumentError('الرحلة المكتملة يجب أن تحتوي على نقاط مسار.');
    }
  }

  // ============================================================
  // ✅ دوال التحقق من صحة المدخلات (Input Validation)
  // ============================================================

  /// ✅ التحقق من طول النص ورمي خطأ إذا تجاوز الحد
  static String _validateStringLength(
      String value, String fieldName, int maxLength) {
    if (value.length > maxLength) {
      throw ArgumentError('حقل $fieldName يتجاوز الحد الأقصى ($maxLength حرف). '
          'الطول الحالي: ${value.length} حرف.');
    }
    return value;
  }

  /// ✅ التحقق من عدد نقاط المسار (حد أقصى 5000 نقطة)
  static List<RoutePoint>? _validateRoutePoints(List<RoutePoint>? points) {
    if (points == null) return null;
    if (points.length > _maxRoutePoints) {
      throw ArgumentError(
          'عدد نقاط المسار يتجاوز الحد الأقصى ($_maxRoutePoints نقطة). '
          'العدد الحالي: ${points.length} نقطة.');
    }
    return points;
  }

  // ============================================================
  // ✅ تحليل التواريخ
  // ============================================================

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

  // ============================================================
  // ✅ إنشاء من Map (قادم من Firestore)
  // ============================================================

  factory TripModel.fromMap(Map<String, dynamic> map, String docId) {
    List<RoutePoint>? parsedRoute;
    if (map['routePoints'] is List) {
      parsedRoute = (map['routePoints'] as List)
          .map((item) => RoutePoint.parse(item))
          .whereType<RoutePoint>()
          .toList();
    }

    return TripModel(
      id: docId,
      passengerId: map['passengerId'] as String? ?? '',
      driverId: map['driverId'] as String? ?? '',
      pickupPoint: map['pickupPoint'] as String? ?? '',
      dropoffPoint: map['dropoffPoint'] as String? ?? '',
      createdAt: _parseRequiredDate(map['createdAt'], 'createdAt'),
      startedAt: _parseOptionalDate(map['startedAt']),
      completedAt: _parseOptionalDate(map['completedAt']),
      status:
          TripStatusExtension.fromString(map['status'] as String? ?? 'pending'),
      fare: (map['fare'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      routePoints: parsedRoute,
    );
  }

  // ============================================================
  // ✅ التحويل إلى Map (للتخزين في Firestore)
  // ============================================================

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

  // ============================================================
  // ✅ copyWith مع التحقق من صحة المدخلات
  // ============================================================

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
    // ✅ تطبيق التحقق على القيم الجديدة إن وجدت
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
