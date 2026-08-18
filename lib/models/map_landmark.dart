import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع المعلم على خريطة المشروع (طبقة خاصة بالتطبيق فوق Mapbox).
enum MapLandmarkType {
  mosque,
  restaurant,
  university,
  hospital,
  school,
  shop,
  park,
  government,
  other,
}

extension MapLandmarkTypeX on MapLandmarkType {
  String get firestoreValue {
    switch (this) {
      case MapLandmarkType.mosque:
        return 'mosque';
      case MapLandmarkType.restaurant:
        return 'restaurant';
      case MapLandmarkType.university:
        return 'university';
      case MapLandmarkType.hospital:
        return 'hospital';
      case MapLandmarkType.school:
        return 'school';
      case MapLandmarkType.shop:
        return 'shop';
      case MapLandmarkType.park:
        return 'park';
      case MapLandmarkType.government:
        return 'government';
      case MapLandmarkType.other:
        return 'other';
    }
  }

  String get labelAr {
    switch (this) {
      case MapLandmarkType.mosque:
        return 'مسجد';
      case MapLandmarkType.restaurant:
        return 'مطعم';
      case MapLandmarkType.university:
        return 'جامعة';
      case MapLandmarkType.hospital:
        return 'مستشفى';
      case MapLandmarkType.school:
        return 'مدرسة';
      case MapLandmarkType.shop:
        return 'متجر';
      case MapLandmarkType.park:
        return 'حديقة';
      case MapLandmarkType.government:
        return 'مبنى حكومي';
      case MapLandmarkType.other:
        return 'معلم آخر';
    }
  }

  static MapLandmarkType fromString(String? v) {
    switch (v) {
      case 'mosque':
        return MapLandmarkType.mosque;
      case 'restaurant':
        return MapLandmarkType.restaurant;
      case 'university':
        return MapLandmarkType.university;
      case 'hospital':
        return MapLandmarkType.hospital;
      case 'school':
        return MapLandmarkType.school;
      case 'shop':
        return MapLandmarkType.shop;
      case 'park':
        return MapLandmarkType.park;
      case 'government':
        return MapLandmarkType.government;
      default:
        return MapLandmarkType.other;
    }
  }
}

/// حالة اعتماد المعلم.
enum MapLandmarkStatus {
  pending,
  approved,
  rejected,
}

extension MapLandmarkStatusX on MapLandmarkStatus {
  String get firestoreValue {
    switch (this) {
      case MapLandmarkStatus.pending:
        return 'pending';
      case MapLandmarkStatus.approved:
        return 'approved';
      case MapLandmarkStatus.rejected:
        return 'rejected';
    }
  }

  String get labelAr {
    switch (this) {
      case MapLandmarkStatus.pending:
        return 'بانتظار المراجعة';
      case MapLandmarkStatus.approved:
        return 'معتمد';
      case MapLandmarkStatus.rejected:
        return 'مرفوض';
    }
  }

  static MapLandmarkStatus fromString(String? v) {
    switch (v) {
      case 'approved':
        return MapLandmarkStatus.approved;
      case 'rejected':
        return MapLandmarkStatus.rejected;
      default:
        return MapLandmarkStatus.pending;
    }
  }
}

/// معلم خاص بمشروع التطبيق — يُعرض كطبقة واحدة فوق Mapbox ولا يُنشر عالمياً.
class MapLandmark {
  final String id;
  final String name;
  final MapLandmarkType type;
  final double latitude;
  final double longitude;
  final MapLandmarkStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final List<String> searchKeys;

  const MapLandmark({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.status = MapLandmarkStatus.approved,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.notes,
    this.searchKeys = const [],
  });

  bool get isApproved => status == MapLandmarkStatus.approved;

  factory MapLandmark.fromDoc(String id, Map<String, dynamic> data) {
    return MapLandmark(
      id: id,
      name: (data['name'] ?? '').toString().trim(),
      type: MapLandmarkTypeX.fromString(data['type']?.toString()),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      status: MapLandmarkStatusX.fromString(data['status']?.toString()),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
      notes: data['notes']?.toString(),
      searchKeys: (data['searchKeys'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'type': type.firestoreValue,
      'latitude': latitude,
      'longitude': longitude,
      'status': status.firestoreValue,
      'createdBy': createdBy,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (searchKeys.isNotEmpty) 'searchKeys': searchKeys,
    };
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
