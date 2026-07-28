import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String userType; // 'driver' أو 'passenger'
  final String phoneNumber; // ✅ حقل رقم الهاتف (جديد)
  final String busNumber;
  final String route;
  final bool isVerified;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.userType,
    this.phoneNumber = '', // ✅ قيمة افتراضية فارغة
    this.busNumber = '',
    this.route = '',
    this.isVerified = false,
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
      phoneNumber: map['phoneNumber'] ?? '', // ✅ قراءة رقم الهاتف
      busNumber: map['busNumber'] ?? '',
      route: map['route'] ?? '',
      isVerified: map['isVerified'] ?? false,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'userType': userType,
      'phoneNumber': phoneNumber, // ✅ حفظ رقم الهاتف
      'busNumber': busNumber,
      'route': route,
      'isVerified': isVerified,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
