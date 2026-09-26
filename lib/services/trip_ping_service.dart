import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip_ping.dart';

/// رفع نقاط الرحلة التاريخية إلى Firestore على دفعات قابلة لإعادة المحاولة.
class TripPingService {
  TripPingService._();
  static final TripPingService instance = TripPingService._();
  factory TripPingService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tripPings');

  /// عدد محافظ للعمليات في الدفعة الواحدة.
  ///
  /// يبقى أقل بكثير من حد Firestore حتى لا نقترب من سقف العمليات
  /// عند إضافة عمليات أخرى إلى نفس الدفعة مستقبلًا.
  static const int maxBatchSize = 20;

  /// معرف ثابت للنقطة حتى تكون إعادة المحاولة idempotent.
  ///
  /// نفس TripPing ينتج نفس المستند، لذلك إعادة الرفع لا تنشئ سجلًا
  /// تاريخيًا مكررًا إذا كانت نتيجة الشبكة غير مؤكدة بعد commit.
  static String docIdFor(TripPing ping) {
    return '\${ping.tripId}_\${ping.timestamp.microsecondsSinceEpoch}';
  }

  Future<void> uploadBatch(List<TripPing> pings) async {
    if (pings.isEmpty) return;
    if (pings.length > maxBatchSize) {
      throw ArgumentError.value(
        pings.length,
        'pings',
        'دفعة TripPing أكبر من الحد المسموح.',
      );
    }

    final batch = _db.batch();

    for (final ping in pings) {
      if (!ping.isValid) {
        throw const FormatException('Cannot upload invalid TripPing.');
      }

      final ref = _col.doc(docIdFor(ping));
      batch.set(ref, ping.toFirestoreMap());
    }

    await batch.commit();
  }
}
