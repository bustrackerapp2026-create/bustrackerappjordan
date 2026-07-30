import 'package:cloud_firestore/cloud_firestore.dart';

class PickupPointModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String addedBy; // UID of driver or passenger
  final String addedByUserType; // 'driver' أو 'passenger'
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? createdAt;
  final List<String> confirmations; // UIDs of users who confirmed this point
  final int confirmationCount;

  PickupPointModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.addedBy,
    this.addedByUserType = 'driver',
    this.status = 'pending',
    this.createdAt,
    this.confirmations = const [],
    this.confirmationCount = 0,
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
      addedBy: map['addedBy'] ?? '',
      addedByUserType: map['addedByUserType'] ?? 'driver',
      status: map['status'] ?? 'pending',
      createdAt: parsedDate,
      confirmations: List<String>.from(map['confirmations'] ?? []),
      confirmationCount: map['confirmationCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'addedBy': addedBy,
      'addedByUserType': addedByUserType,
      'status': status,
      'confirmations': confirmations,
      'confirmationCount': confirmationCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  PickupPointModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? addedBy,
    String? addedByUserType,
    String? status,
    DateTime? createdAt,
    List<String>? confirmations,
    int? confirmationCount,
  }) {
    return PickupPointModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addedBy: addedBy ?? this.addedBy,
      addedByUserType: addedByUserType ?? this.addedByUserType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      confirmations: confirmations ?? this.confirmations,
      confirmationCount: confirmationCount ?? this.confirmationCount,
    );
  }
}
