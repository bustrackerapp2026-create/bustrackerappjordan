import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_status.dart';

/// نموذج بيانات الرحلة، يمثل رحلة بين نقطة انطلاق ووجهة.
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

  TripModel({
    required this.id,
    required this.passengerId,
    required this.driverId,
    required this.pickupPoint,
    required this.dropoffPoint,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.status = TripStatus.pending,
    this.fare,
    this.notes,
  });

  factory TripModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return TripModel(
      id: docId,
      passengerId: map['passengerId'] ?? '',
      driverId: map['driverId'] ?? '',
      pickupPoint: map['pickupPoint'] ?? '',
      dropoffPoint: map['dropoffPoint'] ?? '',
      createdAt: parseDate(map['createdAt']),
      startedAt: map['startedAt'] != null ? parseDate(map['startedAt']) : null,
      completedAt:
          map['completedAt'] != null ? parseDate(map['completedAt']) : null,
      status: TripStatusExtension.fromString(map['status'] ?? 'pending'),
      fare: (map['fare'] as num?)?.toDouble(),
      notes: map['notes'],
    );
  }

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
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }

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
  }) {
    return TripModel(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      dropoffPoint: dropoffPoint ?? this.dropoffPoint,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      notes: notes ?? this.notes,
    );
  }
}
