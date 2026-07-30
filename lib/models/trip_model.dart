import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String id;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String busNumber;
  final String route;
  final double currentLatitude;
  final double currentLongitude;
  final double heading;
  final double speed;
  final bool isLive;
  final int availableSeats;
  final int totalSeats;
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime? updatedAt;

  const TripModel({
    required this.id,
    required this.driverId,
    this.driverName = '',
    this.driverPhone = '',
    required this.busNumber,
    required this.route,
    this.currentLatitude = 0.0,
    this.currentLongitude = 0.0,
    this.heading = 0.0,
    this.speed = 0.0,
    this.isLive = false,
    this.availableSeats = 20,
    this.totalSeats = 20,
    this.status = 'active',
    this.updatedAt,
  });

  factory TripModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDate;
    if (map['updatedAt'] is Timestamp) {
      parsedDate = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is DateTime) {
      parsedDate = map['updatedAt'] as DateTime;
    }

    return TripModel(
      id: docId,
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      driverPhone: map['driverPhone'] ?? '',
      busNumber: map['busNumber'] ?? '',
      route: map['route'] ?? '',
      currentLatitude: (map['currentLatitude'] as num?)?.toDouble() ?? 0.0,
      currentLongitude: (map['currentLongitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      isLive: map['isLive'] ?? false,
      availableSeats: map['availableSeats'] ?? 20,
      totalSeats: map['totalSeats'] ?? 20,
      status: map['status'] ?? 'active',
      updatedAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'busNumber': busNumber,
      'route': route,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'heading': heading,
      'speed': speed,
      'isLive': isLive,
      'availableSeats': availableSeats,
      'totalSeats': totalSeats,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TripModel copyWith({
    String? id,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? busNumber,
    String? route,
    double? currentLatitude,
    double? currentLongitude,
    double? heading,
    double? speed,
    bool? isLive,
    int? availableSeats,
    int? totalSeats,
    String? status,
    DateTime? updatedAt,
  }) {
    return TripModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      busNumber: busNumber ?? this.busNumber,
      route: route ?? this.route,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      isLive: isLive ?? this.isLive,
      availableSeats: availableSeats ?? this.availableSeats,
      totalSeats: totalSeats ?? this.totalSeats,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
