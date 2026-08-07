import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات نقطة التجمع (يُستخدم في PickupPointService)
class PickupPointModel {
  static const int _maxNameLength = 100;
  static const List<String> _validStatuses = [
    'pending',
    'approved',
    'rejected'
  ];
  static const List<String> _validPointTypes = ['bus', 'passenger'];

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String addedBy;
  final String addedByUserType;
  final String status;
  final String pointType;
  final DateTime? createdAt;
  final List<String> confirmations;
  final int confirmationCount;

  PickupPointModel({
    required this.id,
    required String name,
    required double latitude,
    required double longitude,
    required this.addedBy,
    this.addedByUserType = 'driver',
    String? status,
    String? pointType,
    this.createdAt,
    this.confirmations = const [],
    this.confirmationCount = 0,
  })  : // ✅ تعيين القيم في قائمة التهيئة فقط
        name = _validateName(name),
        latitude = _validateLatitude(latitude),
        longitude = _validateLongitude(longitude),
        status = _validateStatus(status ?? 'pending'),
        pointType = _validatePointType(pointType ?? 'bus');

  // ============================================================
  // ✅ دوال التحقق من صحة المدخلات (Validation)
  // ============================================================

  static String _validateName(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('اسم نقطة التجمع لا يمكن أن يكون فارغاً.');
    }
    if (value.length > _maxNameLength) {
      throw ArgumentError(
          'اسم نقطة التجمع يتجاوز الحد الأقصى ($_maxNameLength حرف). '
          'الطول الحالي: ${value.length} حرف.');
    }
    return value.trim();
  }

  static double _validateLatitude(double value) {
    if (value < -90 || value > 90) {
      throw ArgumentError('خط العرض يجب أن يكون بين -90 و 90. القيمة: $value');
    }
    return value;
  }

  static double _validateLongitude(double value) {
    if (value < -180 || value > 180) {
      throw ArgumentError(
          'خط الطول يجب أن يكون بين -180 و 180. القيمة: $value');
    }
    return value;
  }

  static String _validateStatus(String value) {
    if (!_validStatuses.contains(value)) {
      throw ArgumentError(
          'حالة غير صالحة: $value. يجب أن تكون أحد: ${_validStatuses.join(', ')}');
    }
    return value;
  }

  static String _validatePointType(String value) {
    if (!_validPointTypes.contains(value)) {
      throw ArgumentError(
          'نوع نقطة غير صالح: $value. يجب أن يكون أحد: ${_validPointTypes.join(', ')}');
    }
    return value;
  }

  // ============================================================
  // ✅ تحليل التواريخ
  // ============================================================

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw FormatException('Invalid date format for createdAt: $value');
  }

  // ============================================================
  // ✅ إنشاء من Map (قادم من Firestore)
  // ============================================================

  factory PickupPointModel.fromMap(Map<String, dynamic> map, String docId) {
    return PickupPointModel(
      id: docId,
      name: map['name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      addedBy: map['addedBy'] as String? ?? '',
      addedByUserType: map['addedByUserType'] as String? ?? 'driver',
      status: map['status'] as String? ?? 'pending',
      pointType: map['pointType'] as String? ?? 'bus',
      createdAt: _parseOptionalDate(map['createdAt']),
      confirmations: List<String>.from(map['confirmations'] ?? []),
      confirmationCount: map['confirmationCount'] ?? 0,
    );
  }

  /// ✅ إنشاء كائن من مستند Firestore مباشرة
  factory PickupPointModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PickupPointModel.fromMap(data, doc.id);
  }

  // ============================================================
  // ✅ التحويل إلى Map (للتخزين في Firestore)
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'addedBy': addedBy,
      'addedByUserType': addedByUserType,
      'status': status,
      'pointType': pointType,
      'confirmations': confirmations,
      'confirmationCount': confirmationCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ============================================================
  // ✅ copyWith مع دعم تعيين القيم إلى null
  // ============================================================

  PickupPointModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? addedBy,
    String? addedByUserType,
    String? status,
    String? pointType,
    DateTime? createdAt,
    List<String>? confirmations,
    int? confirmationCount,
  }) {
    return PickupPointModel(
      id: id ?? this.id,
      name: name != null ? _validateName(name) : this.name,
      latitude: latitude != null ? _validateLatitude(latitude) : this.latitude,
      longitude:
          longitude != null ? _validateLongitude(longitude) : this.longitude,
      addedBy: addedBy ?? this.addedBy,
      addedByUserType: addedByUserType ?? this.addedByUserType,
      status: status != null ? _validateStatus(status) : this.status,
      pointType: pointType != null ? _validatePointType(pointType) : this.pointType,
      createdAt: createdAt ?? this.createdAt,
      confirmations: confirmations ?? this.confirmations,
      confirmationCount: confirmationCount ?? this.confirmationCount,
    );
  }

  // ============================================================
  // ✅ دوال مساعدة
  // ============================================================

  /// ✅ التحقق مما إذا كانت النقطة معلقة (في انتظار المراجعة)
  bool get isPending => status == 'pending';

  /// ✅ التحقق مما إذا كانت النقطة معتمدة
  bool get isApproved => status == 'approved';

  /// ✅ التحقق مما إذا كانت النقطة مرفوضة
  bool get isRejected => status == 'rejected';

  /// ✅ التحقق مما إذا كانت النقطة قابلة للتعديل (معلقة فقط)
  bool get isEditable => status == 'pending';

  /// ✅ إضافة تأكيد من مستخدم
  PickupPointModel addConfirmation(String userId) {
    if (confirmations.contains(userId)) return this;
    final newConfirmations = List<String>.from(confirmations)..add(userId);
    return copyWith(
      confirmations: newConfirmations,
      confirmationCount: newConfirmations.length,
    );
  }

  /// ✅ إزالة تأكيد من مستخدم
  PickupPointModel removeConfirmation(String userId) {
    if (!confirmations.contains(userId)) return this;
    final newConfirmations = List<String>.from(confirmations)..remove(userId);
    return copyWith(
      confirmations: newConfirmations,
      confirmationCount: newConfirmations.length,
    );
  }

  @override
  String toString() =>
      'PickupPointModel(id: $id, name: $name, status: $status, confirmations: ${confirmations.length})';
}
