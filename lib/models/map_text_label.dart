import 'package:cloud_firestore/cloud_firestore.dart';

/// تسمية نصية على الخريطة (مثل اسم شارع) مع حجم واتجاه قابلين للضبط.
class MapTextLabel {
  final String id;
  final String text;
  final double latitude;
  final double longitude;

  /// حجم النص على الخريطة (عادة 10–28).
  final double fontSize;

  /// دوران النص بالدرجات [0..360) — 0 = أفقي.
  final double rotation;

  /// لون النص بصيغة ARGB (مثل 0xFF1A1A1A).
  final int colorArgb;

  final String status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MapTextLabel({
    required this.id,
    required this.text,
    required this.latitude,
    required this.longitude,
    this.fontSize = 14,
    this.rotation = 0,
    this.colorArgb = 0xFF1A237E,
    this.status = 'approved',
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isApproved => status == 'approved';

  factory MapTextLabel.fromDoc(String id, Map<String, dynamic> data) {
    return MapTextLabel(
      id: id,
      text: (data['text'] ?? '').toString().trim(),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      fontSize: (data['fontSize'] as num?)?.toDouble() ?? 14,
      rotation: (data['rotation'] as num?)?.toDouble() ?? 0,
      colorArgb: (data['colorArgb'] as num?)?.toInt() ?? 0xFF1A237E,
      status: (data['status'] ?? 'approved').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'fontSize': fontSize.clamp(8, 36),
      'rotation': rotation % 360,
      'colorArgb': colorArgb,
      'status': status,
      'createdBy': createdBy,
    };
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
