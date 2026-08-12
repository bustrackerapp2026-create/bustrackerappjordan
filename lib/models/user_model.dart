import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/bus_capacity.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String userType;
  final String? phoneNumber;
  final String? busNumber;
  final String? route;
  final String? photoUrl;
  /// سعة الباص: 5 (سرفيس) / 23 (متوسط) / 50 (كبير) — للسائقين فقط.
  final int? capacity;
  final bool isVerified;
  final bool isRejected;
  final DateTime? createdAt;

  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.userType,
    this.phoneNumber,
    this.busNumber,
    this.route,
    this.photoUrl,
    this.capacity,
    this.isVerified = false,
    this.isRejected = false,
    this.createdAt,
  });

  // ─── دوال Factory (من Firestore) ──────────────────────────────────

  /// ✅ إنشاء UserModel من خريطة Firestore (الدالة الأساسية)
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      email: _safeEmail(map['email']),
      fullName: map['fullName']?.toString() ?? '',
      userType: map['userType']?.toString() ?? 'passenger',
      phoneNumber: _safePhoneNumber(map['phoneNumber']),
      busNumber: map['busNumber'] as String?,
      route: map['route'] as String?,
      photoUrl: map['photoUrl'] as String?,
      capacity: BusCapacity.normalize(map['capacity']),
      isVerified: map['isVerified'] == true,
      isRejected: map['isRejected'] == true,
      createdAt: _parseOptionalDate(map['createdAt']),
    );
  }

  /// ✅ إنشاء UserModel من Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  // ─── دوال التحويل إلى Map ──────────────────────────────────────

  /// ✅ تحويل UserModel إلى خريطة للتخزين في Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'userType': userType,
      'phoneNumber': phoneNumber,
      'busNumber': busNumber,
      'route': route,
      'photoUrl': photoUrl,
      'capacity': capacity,
      'isVerified': isVerified,
      'isRejected': isRejected,
    };
  }

  // ─── دوال مساعدة (تحويل JSON) ──────────────────────────────────

  /// ✅ تحويل UserModel إلى JSON (لـ API)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'userType': userType,
      'phoneNumber': phoneNumber,
      'busNumber': busNumber,
      'route': route,
      'photoUrl': photoUrl,
      'capacity': capacity,
      'isVerified': isVerified,
      'isRejected': isRejected,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// ✅ إنشاء UserModel من JSON (لـ API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      userType: json['userType'] ?? 'passenger',
      phoneNumber: json['phoneNumber'] as String?,
      busNumber: json['busNumber'] as String?,
      route: json['route'] as String?,
      photoUrl: json['photoUrl'] as String?,
      capacity: BusCapacity.normalize(json['capacity']),
      isVerified: json['isVerified'] ?? false,
      isRejected: json['isRejected'] ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  // ─── دوال مُحدِّثة ─────────────────────────────────────────────

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? userType,
    String? phoneNumber,
    String? busNumber,
    String? route,
    String? photoUrl,
    int? capacity,
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
      photoUrl: photoUrl ?? this.photoUrl,
      capacity: capacity ?? this.capacity,
      isVerified: isVerified ?? this.isVerified,
      isRejected: isRejected ?? this.isRejected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─── دوال مساعدة (Getters) ─────────────────────────────────────

  String get displayName => fullName.isNotEmpty ? fullName : 'مستخدم';
  String get displayPhone =>
      phoneNumber?.isNotEmpty == true ? phoneNumber! : 'غير محدد';
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  String get displayCapacity => BusCapacity.label(capacity);

  String get displayUserType {
    switch (userType) {
      case 'admin':
        return 'مشرف';
      case 'driver':
        return 'سائق';
      case 'passenger':
        return 'راكب';
      case 'service':
        return 'سرفيس';
      case 'bus_company':
        return 'باص شركه';
      default:
        return userType;
    }
  }

  // ─── دوال مساعدة (Private) ─────────────────────────────────────

  static String _safeEmail(dynamic email) {
    final str = email?.toString().trim() ?? '';
    if (str.isNotEmpty && _emailRegex.hasMatch(str)) {
      return str;
    }
    return str;
  }

  static String? _safePhoneNumber(dynamic phone) {
    if (phone == null) return null;
    final str = phone.toString().replaceAll(' ', '');
    if (str.isEmpty) return null;
    return str;
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
