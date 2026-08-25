/// أدوار المستخدمين في التطبيق — مصدر الحقيقة الوحيد للنصوص والتحقق.
///
/// يجب أن تبقى القيم متوافقة مع:
/// - `firestore.rules` (isAllowedSelfUserType / isAdmin / isDriver ...)
/// - حقل `userType` في مستندات `users`
abstract final class UserRoles {
  static const String admin = 'admin';
  static const String driver = 'driver';
  static const String passenger = 'passenger';

  /// سرفيس (مركبة صغيرة)
  static const String service = 'service';

  /// باص شركة
  static const String busCompany = 'bus_company';

  /// كل الأدوار المعروفة في النظام.
  static const List<String> all = [
    admin,
    driver,
    passenger,
    service,
    busCompany,
  ];

  /// أدوار يمكن للمستخدم اختيارها عند التسجيل الذاتي
  /// (متوافق مع `isAllowedSelfUserType` في قواعد Firestore).
  static const List<String> selfRegistrable = [
    passenger,
    driver,
    service,
    busCompany,
  ];

  /// أدوار تحتاج موافقة أدمن قبل تفعيل الحساب الكامل
  /// (سائق / سرفيس / باص شركة).
  static const List<String> requiresVerification = [
    driver,
    service,
    busCompany,
  ];

  /// أدوار تُعامل كمشغّل مركبة (تتبع موقع، خطوط، طلبات صعود).
  static const List<String> driverLike = [
    driver,
    service,
    busCompany,
  ];

  static bool isKnown(String? type) =>
      type != null && all.contains(type);

  static bool isAdmin(String? type) => type == admin;

  static bool isPassenger(String? type) => type == passenger;

  static bool isDriver(String? type) => type == driver;

  /// سائق أو سرفيس أو باص شركة.
  static bool isDriverLike(String? type) =>
      type != null && driverLike.contains(type);

  static bool needsVerification(String? type) =>
      type != null && requiresVerification.contains(type);

  static bool canSelfRegister(String? type) =>
      type != null && selfRegistrable.contains(type);

  /// تسمية عربية للعرض في الواجهة.
  static String displayLabelAr(String? type) {
    switch (type) {
      case admin:
        return 'مشرف';
      case driver:
        return 'سائق';
      case passenger:
        return 'راكب';
      case service:
        return 'سرفيس';
      case busCompany:
        return 'باص شركة';
      default:
        return type?.isNotEmpty == true ? type! : 'غير محدد';
    }
  }

  /// تسمية إنجليزية مختصرة (سجلات / تحليلات).
  static String displayLabelEn(String? type) {
    switch (type) {
      case admin:
        return 'admin';
      case driver:
        return 'driver';
      case passenger:
        return 'passenger';
      case service:
        return 'service';
      case busCompany:
        return 'bus_company';
      default:
        return type?.isNotEmpty == true ? type! : 'unknown';
    }
  }
}
