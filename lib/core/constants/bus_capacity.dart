/// سعات الباص المتاحة للسائق وكيف تظهر للراكب على الخريطة.
class BusCapacity {
  BusCapacity._();

  static const int service = 5;
  static const int medium = 23;
  static const int large = 50;

  static const List<int> options = [service, medium, large];

  /// تسمية عربية للعرض في القوائم والواجهات.
  static String label(int? capacity) {
    switch (capacity) {
      case service:
        return 'سرفيس (5 ركاب)';
      case medium:
        return 'باص متوسط (23 راكب)';
      case large:
        return 'باص كبير (50 راكب)';
      default:
        return 'غير محدد';
    }
  }

  /// وصف قصير يظهر على الخريطة / الحالة.
  static String shortLabel(int? capacity) {
    switch (capacity) {
      case service:
        return 'سرفيس';
      case medium:
        return 'باص متوسط';
      case large:
        return 'باص كبير';
      default:
        return 'باص';
    }
  }

  /// تطبيع أي قيمة واردة من Firestore إلى أحد الخيارات المعتمدة.
  static int? normalize(dynamic raw) {
    if (raw == null) return null;
    final n = raw is int ? raw : int.tryParse(raw.toString());
    if (n == null) return null;
    if (options.contains(n)) return n;
    // تقريب لأقرب خيار معروف
    if (n <= 10) return service;
    if (n <= 35) return medium;
    return large;
  }
}
