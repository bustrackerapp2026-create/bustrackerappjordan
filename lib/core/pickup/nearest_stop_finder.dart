import '../../models/pickup_point_model.dart';
import '../../services/pickup_point_service.dart';
import '../trip/eta_utils.dart';

/// نتيجة أقرب محطة معتمدة من موقع الراكب.
class NearestStopResult {
  final PickupPointModel stop;
  final double meters;

  const NearestStopResult({required this.stop, required this.meters});
}

class NearestStopFinder {
  NearestStopFinder._();

  static final PickupPointService _service = PickupPointService();

  /// أقصى مسافة مقبولة لاعتبار المحطة «قريبة» (متر).
  static const double defaultMaxMeters = 900;

  /// يجلب النقاط المعتمدة ويختار الأقرب لموقع الراكب.
  static Future<NearestStopResult?> findNearestApproved({
    required double lat,
    required double lng,
    double maxMeters = defaultMaxMeters,
  }) async {
    try {
      final snap = await _service.getApprovedPointsStream().first;
      NearestStopResult? best;

      for (final p in snap) {
        if (!p.isApproved) continue;
        if (p.latitude == 0 && p.longitude == 0) continue;
        final m = EtaUtils.distanceMeters(lat, lng, p.latitude, p.longitude);
        if (m > maxMeters) continue;
        if (best == null || m < best.meters) {
          best = NearestStopResult(stop: p, meters: m);
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }
}
