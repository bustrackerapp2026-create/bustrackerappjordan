import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String userType;
  final String phoneNumber;
  final String busNumber;
  final String route;
  final bool isVerified;
  final bool isRejected; // ✅ حقل جديد
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.userType,
    this.phoneNumber = '',
    this.busNumber = '',
    this.route = '',
    this.isVerified = false,
    this.isRejected = false, // ✅ قيمة افتراضية
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDate;
    if (map['createdAt'] is Timestamp) {
      parsedDate = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is DateTime) {
      parsedDate = map['createdAt'] as DateTime;
    }

    return UserModel(
      uid: docId,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      userType: map['userType'] ?? 'passenger',
      phoneNumber: map['phoneNumber'] ?? '',
      busNumber: map['busNumber'] ?? '',
      route: map['route'] ?? '',
      isVerified: map['isVerified'] ?? false,
      isRejected: map['isRejected'] ?? false, // ✅ قراءة الحقل
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'userType': userType,
      'phoneNumber': phoneNumber,
      'busNumber': busNumber,
      'route': route,
      'isVerified': isVerified,
      'isRejected': isRejected, // ✅ حفظ الحقل
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? userType,
    String? phoneNumber,
    String? busNumber,
    String? route,
    bool? isVerified,
    bool? isRejected,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      userType: userType ?? this.userType,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      busNumber: busNumber ?? this.busNumber,
      route: route ?? this.route,
      isVerified: isVerified ?? this.isVerified,
      isRejected: isRejected ?? this.isRejected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
