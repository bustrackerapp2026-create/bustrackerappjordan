import '../models/trip_ping.dart';

/// ذاكرة مؤقتة محدودة لنقاط الرحلة التاريخية قبل رفعها إلى Firestore.
///
/// لا تقوم هذه الطبقة بأي اتصال بالشبكة ولا تعرف شيئًا عن GPS.
/// دورها فقط الاحتفاظ بترتيب TripPing داخل حد أقصى واضح.
class TripPingBuffer {
  TripPingBuffer({this.maxSize = 100}) {
    if (maxSize <= 0) {
      throw ArgumentError.value(
        maxSize,
        'maxSize',
        'يجب أن يكون الحد الأقصى أكبر من صفر.',
      );
    }
  }

  final int maxSize;
  final List<TripPing> _items = <TripPing>[];

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isFull => _items.length >= maxSize;

  /// يضيف نقطة إذا كان هناك مكان.
  ///
  /// عند الامتلاء لا تُحذف نقاط قديمة تلقائيًا؛ تعاد false
  /// حتى تحدد طبقة الرفع لاحقًا سياسة التعامل مع الامتلاء.
  bool tryAdd(TripPing ping) {
    if (!ping.isValid || isFull) return false;
    _items.add(ping);
    return true;
  }

  /// يعرض نسخة للقراءة فقط دون السماح بتعديل الذاكرة الداخلية.
  List<TripPing> get items => List<TripPing>.unmodifiable(_items);

  /// يسحب أول مجموعة من النقاط بترتيب وصولها.
  List<TripPing> takeBatch(int maxItems) {
    if (maxItems <= 0 || _items.isEmpty) return const <TripPing>[];

    final count = maxItems > _items.length ? _items.length : maxItems;
    final batch = List<TripPing>.of(_items.take(count));
    _items.removeRange(0, count);
    return batch;
  }

  /// يسحب جميع النقاط الحالية.
  List<TripPing> drain() {
    if (_items.isEmpty) return const <TripPing>[];

    final batch = List<TripPing>.of(_items);
    _items.clear();
    return batch;
  }

  void clear() => _items.clear();
}
