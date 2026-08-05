import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String id;
  final String name;
  final String startCity;
  final String endCity;
  final String vehicleType;
  final String routeColor;
  final double distanceKm;
  final int estimatedDuration;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RouteModel({
    required this.id,
    required this.name,
    required this.startCity,
    required this.endCity,
    required this.vehicleType,
    required this.routeColor,
    required this.distanceKm,
    required this.estimatedDuration,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final now = DateTime.now();

    return RouteModel(
      id: doc.id,
      name: data['name'] as String? ?? 'بدون اسم',
      startCity: data['startCity'] as String? ?? '',
      endCity: data['endCity'] as String? ?? '',
      vehicleType: data['vehicleType'] as String? ?? 'bus',
      routeColor: data['routeColor'] as String? ?? '#2196F3',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedDuration: (data['estimatedDuration'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startCity': startCity,
      'endCity': endCity,
      'vehicleType': vehicleType,
      'routeColor': routeColor,
      'distanceKm': distanceKm,
      'estimatedDuration': estimatedDuration,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
