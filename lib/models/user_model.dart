import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String userType;
  final String? phoneNumber; // ✅ أصبح قابلاً للـ null
  final String? busNumber; // ✅ أصبح قابلاً للـ null
  final String? route; // ✅ أصبح قابلاً للـ null
  final bool isVerified;
  final bool isRejected;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.userType,
    this.phoneNumber,
    this.busNumber,
    this.route,
    this.isVerified = false,
    this.isRejected = false,
    this.createdAt,
  });

  // ============================================================
  // ✅ دوال التحقق من صحة المدخلات (Input Validation)
  // ============================================================

  /// ✅ التحقق من صيغة البريد الإلكتروني (صيغة قياسية)
  static String _validateEmail(String email) {
    if (email.isEmpty) {
      throw ArgumentError('البريد الإلكتروني مطلوب.');
    }
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    if (!emailRegex.hasMatch(email)) {
      throw ArgumentError('صيغة البريد الإلكتروني غير صحيحة: $email');
    }
    return email;
  }

  /// ✅ التحقق من رقم الهاتف (يسمح بتركه فارغاً أو 10-12 رقماً مع +962 اختياري)
  static String? _validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // ✅ رقم الهاتف غير مطلوب
    }
    final phoneRegex = RegExp(
      r'^(?:\+962)?[0-9]{10,12}$',
    );
    if (!phoneRegex.hasMatch(phone.replaceAll(' ', ''))) {
      throw ArgumentError('صيغة رقم الهاتف غير صحيحة: $phone');
    }
    return phone;
  }

  // ============================================================
  // ✅ تحليل التواريخ
  // ============================================================

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    throw FormatException('Invalid date format for createdAt: $value');
  }

  // ============================================================
  // ✅ إنشاء من Map (قادم من Firestore)
  // ============================================================

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      email: _validateEmail(map['email'] ?? ''),
      fullName: map['fullName'] ?? '',
      userType: map['userType'] ?? 'passenger',
      phoneNumber: _validatePhoneNumber(map['phoneNumber'] as String?),
      busNumber: map['busNumber'] as String?,
      route: map['route'] as String?,
      isVerified: map['isVerified'] ?? false,
      isRejected: map['isRejected'] ?? false,
      createdAt: _parseOptionalDate(map['createdAt']),
    );
  }

  // ============================================================
  // ✅ التحويل إلى Map (للتخزين في Firestore)
  // ============================================================

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
      'isRejected': isRejected,
    };
  }

  // ============================================================
  // ✅ copyWith مع دعم تعيين القيم إلى null
  // ============================================================

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? userType,
    String? phoneNumber, // ✅ يمكن تمرير null لمسح القيمة
    String? busNumber, // ✅ يمكن تمرير null لمسح القيمة
    String? route, // ✅ يمكن تمرير null لمسح القيمة
    bool? isVerified,
    bool? isRejected,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email != null ? _validateEmail(email) : this.email,
      fullName: fullName ?? this.fullName,
      userType: userType ?? this.userType,
      phoneNumber: phoneNumber, // ✅ قبول null مباشرة
      busNumber: busNumber, // ✅ قبول null مباشرة
      route: route, // ✅ قبول null مباشرة
      isVerified: isVerified ?? this.isVerified,
      isRejected: isRejected ?? this.isRejected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ============================================================
  // ✅ دوال مساعدة للاستخدام في التطبيق
  // ============================================================

  /// ✅ الحصول على اسم المستخدم للعرض (اختصار)
  String get displayName => fullName.isNotEmpty ? fullName : 'مستخدم';

  /// ✅ الحصول على رقم الهاتف مع تنسيق أو رسالة افتراضية
  String get displayPhone =>
      phoneNumber?.isNotEmpty == true ? phoneNumber! : 'غير محدد';
}
