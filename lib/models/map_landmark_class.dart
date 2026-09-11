part of 'map_landmark.dart';

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
        return 'قيد المراجعة';
      case MapLandmarkStatus.approved:
        return 'معتمد';
      case MapLandmarkStatus.rejected:
        return 'مرفوض';
    }
  }

  static MapLandmarkStatus fromString(String? v) {
    switch ((v ?? '').toLowerCase().trim()) {
      case 'approved':
        return MapLandmarkStatus.approved;
      case 'rejected':
        return MapLandmarkStatus.rejected;
      default:
        return MapLandmarkStatus.pending;
    }
  }
}

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
