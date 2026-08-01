/// نموذج يمثل نقطة تجمع يضيفها السائق أو الراكب
class PickupPoint {
  static const int _maxNameLength = 100;

  final String name;
  final double latitude;
  final double longitude;

  // ✅ إزالة const و this من المعاملات
  PickupPoint({
    required String name,
    required double latitude,
    required double longitude,
  })  : name = _validateName(name),
        latitude = _validateLatitude(latitude),
        longitude = _validateLongitude(longitude);

  // ============================================================
  // ✅ دوال التحقق من صحة المدخلات (Validation)
  // ============================================================

  static String _validateName(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('اسم نقطة التجمع لا يمكن أن يكون فارغاً.');
    }
    if (value.length > _maxNameLength) {
      throw ArgumentError(
          'اسم نقطة التجمع يتجاوز الحد الأقصى ($_maxNameLength حرف).');
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

  // ============================================================
  // ✅ تحويلات JSON / Map
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory PickupPoint.fromMap(Map<String, dynamic> map) {
    return PickupPoint(
      name: map['name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ============================================================
  // ✅ دوال مساعدة
  // ============================================================

  bool get isValid {
    return name.isNotEmpty &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// ✅ نسخة معدلة من الكائن
  PickupPoint copyWith({
    String? name,
    double? latitude,
    double? longitude,
  }) {
    return PickupPoint(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() =>
      'PickupPoint(name: $name, lat: $latitude, lng: $longitude)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PickupPoint &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;
}
