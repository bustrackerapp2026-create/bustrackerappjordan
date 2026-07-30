import 'package:cloud_firestore/cloud_firestore.dart';

class PickupPointModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String route;
  final String requestedBy;
  final bool isApproved;
  final DateTime? createdAt;

  const PickupPointModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.route,
    this.requestedBy = '',
    this.isApproved = false,
    this.createdAt,
  });

  factory PickupPointModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDate;
    if (map['createdAt'] is Timestamp) {
      parsedDate = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is DateTime) {
      parsedDate = map['createdAt'] as DateTime;
    }

    return PickupPointModel(
      id: docId,
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      route: map['route'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      isApproved: map['isApproved'] ?? false,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'route': route,
      'requestedBy': requestedBy,
      'isApproved': isApproved,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  PickupPointModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? route,
    String? requestedBy,
    bool? isApproved,
    DateTime? createdAt,
  }) {
    return PickupPointModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      route: route ?? this.route,
      requestedBy: requestedBy ?? this.requestedBy,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
