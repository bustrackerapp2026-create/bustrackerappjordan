import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/bus_capacity.dart';
import '../core/constants/user_roles.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String userType;
  final String? phoneNumber;
  final String? busNumber;

  /// اتجاه الخط العام (من → إلى)
  final String? route;

  /// تفاصيل مسار الخط (المناطق بالترتيب)
  final String? routeDetail;

  final String? photoUrl;
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
    this.routeDetail,
    this.photoUrl,
    this.capacity,
    this.isVerified = false,
    this.isRejected = false,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      email: _safeEmail(map['email']),
      fullName: map['fullName']?.toString() ?? '',
      userType: map['userType']?.toString() ?? UserRoles.passenger,
      phoneNumber: _safePhoneNumber(map['phoneNumber']),
      busNumber: map['busNumber'] as String?,
      route: map['route'] as String?,
      routeDetail: map['routeDetail'] as String?,
      photoUrl: map['photoUrl'] as String?,
      capacity: BusCapacity.normalize(map['capacity']),
      isVerified: map['isVerified'] == true,
      isRejected: map['isRejected'] == true,
      createdAt: _parseOptionalDate(map['createdAt']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
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
      'routeDetail': routeDetail,
      'photoUrl': photoUrl,
      'capacity': capacity,
      'isVerified': isVerified,
      'isRejected': isRejected,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'userType': userType,
      'phoneNumber': phoneNumber,
      'busNumber': busNumber,
      'route': route,
      'routeDetail': routeDetail,
      'photoUrl': photoUrl,
      'capacity': capacity,
      'isVerified': isVerified,
      'isRejected': isRejected,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      userType: json['userType'] ?? UserRoles.passenger,
      phoneNumber: json['phoneNumber'] as String?,
      busNumber: json['busNumber'] as String?,
      route: json['route'] as String?,
      routeDetail: json['routeDetail'] as String?,
      photoUrl: json['photoUrl'] as String?,
      capacity: BusCapacity.normalize(json['capacity']),
      isVerified: json['isVerified'] ?? false,
      isRejected: json['isRejected'] ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? userType,
    String? phoneNumber,
    String? busNumber,
    String? route,
    String? routeDetail,
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
      routeDetail: routeDetail ?? this.routeDetail,
      photoUrl: photoUrl ?? this.photoUrl,
      capacity: capacity ?? this.capacity,
      isVerified: isVerified ?? this.isVerified,
      isRejected: isRejected ?? this.isRejected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayName => fullName.isNotEmpty ? fullName : 'مستخدم';
  String get displayPhone =>
      phoneNumber?.isNotEmpty == true ? phoneNumber! : 'غير محدد';
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  String get displayCapacity => BusCapacity.label(capacity);

  String get displayUserType => UserRoles.displayLabelAr(userType);

  bool get isAdminRole => UserRoles.isAdmin(userType);
  bool get isPassengerRole => UserRoles.isPassenger(userType);
  bool get isDriverRole => UserRoles.isDriver(userType);
  bool get isDriverLikeRole => UserRoles.isDriverLike(userType);
  bool get needsVerification => UserRoles.needsVerification(userType);

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
