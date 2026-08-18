import 'dart:math' as math;

import '../models/planned_route.dart';
import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_plan_service.dart';

/// نتيجة خط قريب من موقع الراكب (وربما الوجهة).
class NearbyLineMatch {
  final String lineName;
  final RouteDirection direction;
  final double distanceMeters;
  final PlannedRoute route;

  /// مسافة الوجهة عن المسار (إن وُجدت).
  final double? destinationDistanceMeters;

  /// هل الوجهة على نفس اتجاه المسار بعد نقطة الراكب؟
  final bool towardsDestination;

  const NearbyLineMatch({
    required this.lineName,
    required this.direction,
    required this.distanceMeters,
    required this.route,
    this.destinationDistanceMeters,
    this.towardsDestination = true,
  });
}

/// يكتشف المسارات المعتمدة التي تمر قرب موقع الراكب و/أو الوجهة.
class NearbyRoutesService {
  NearbyRoutesService._();
  static final NearbyRoutesService instance = NearbyRoutesService._();
  factory NearbyRoutesService() => instance;

  final RoutePlanService _plans = RoutePlanService();

  List<PlannedRoute>? _cache;
  DateTime? _cacheAt;
  static const Duration _cacheTtl = Duration(minutes: 3);

  /// أقصى مسافة (متر) لاعتبار أن الخط يمر من موقع الراكب.
  static const double defaultMaxDistanceM = 180;

  /// سماحية أوسع قليلاً لمنطقة الوجهة.
  static const double defaultDestMaxDistanceM = 280;

  Future<List<PlannedRoute>> _approvedRoutes({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _cacheTtl) {
      return _cache!;
    }
    final list = await _plans.listApprovedRoutes(limit: 120);
    _cache = list;
    _cacheAt = now;
    return list;
  }

  void clearCache() {
    _cache = null;
    _cacheAt = null;
  }

  static double distanceToPolylineMeters(
    double lat,
    double lng,
    List<RoutePoint> points,
  ) {
    if (points.isEmpty) return double.infinity;
    if (points.length == 1) {
      return RoutePlanGeometry.distanceMeters(
        lat,
        lng,
        points.first.latitude,
        points.first.longitude,
      );
    }
    var best = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = distanceToSegmentMeters(
        lat,
        lng,
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
      if (d < best) best = d;
    }
    return best;
  }

  static double distanceToSegmentMeters(
    double lat,
    double lng,
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final lat0 = ((lat1 + lat2) / 2) * math.pi / 180.0;
    final x = lng * 111320.0 * math.cos(lat0);
    final y = lat * 110540.0;
    final x1 = lng1 * 111320.0 * math.cos(lat0);
    final y1 = lat1 * 110540.0;
    final x2 = lng2 * 111320.0 * math.cos(lat0);
    final y2 = lat2 * 110540.0;
    final dx = x2 - x1;
    final dy = y2 - y1;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) {
      final ddx = x - x1;
      final ddy = y - y1;
      return math.sqrt(ddx * ddx + ddy * ddy);
    }
    var t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final sx = x1 + t * dx;
    final sy = y1 + t * dy;
    final ddx = x - sx;
    final ddy = y - sy;
    return math.sqrt(ddx * ddx + ddy * ddy);
  }

  /// موقع تقريبي على المسار [0..1] لأقرب نقطة من (lat,lng).
  static double progressAlongRoute(
    double lat,
    double lng,
    List<RoutePoint> points,
  ) {
    if (points.length < 2) return 0;
    var bestD = double.infinity;
    var bestProgress = 0.0;
    final n = points.length - 1;
    for (var i = 0; i < n; i++) {
      final d = distanceToSegmentMeters(
        lat,
        lng,
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
      if (d < bestD) {
        bestD = d;
        bestProgress = i / n;
      }
    }
    return bestProgress.clamp(0.0, 1.0);
  }

  Future<List<NearbyLineMatch>> findNearbyLines({
    required double latitude,
    required double longitude,
    double maxDistanceM = defaultMaxDistanceM,
    int limit = 8,
  }) async {
    final routes = await _approvedRoutes();
    if (routes.isEmpty) return const [];

    final matches = <NearbyLineMatch>[];
    for (final r in routes) {
      if (r.points.length < 2) continue;
      final d = distanceToPolylineMeters(latitude, longitude, r.points);
      if (d <= maxDistanceM) {
        matches.add(NearbyLineMatch(
          lineName: r.lineName,
          direction: r.direction,
          distanceMeters: d,
          route: r,
        ));
      }
    }

    return _dedupeBestByLine(matches, limit: limit);
  }

  /// خطوط تمر قرب نقطة الانطلاق والوجهة، مع تفضيل الاتجاه الصحيح.
  Future<List<NearbyLineMatch>> findLinesServingTrip({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    double originMaxDistanceM = defaultMaxDistanceM,
    double destMaxDistanceM = defaultDestMaxDistanceM,
    int limit = 8,
  }) async {
    final routes = await _approvedRoutes();
    if (routes.isEmpty) return const [];

    final candidates = <NearbyLineMatch>[];

    for (final r in routes) {
      if (r.points.length < 2) continue;

      final dFrom = distanceToPolylineMeters(fromLat, fromLng, r.points);
      if (dFrom > originMaxDistanceM) continue;

      final dTo = distanceToPolylineMeters(toLat, toLng, r.points);
      if (dTo > destMaxDistanceM) continue;

      final pFrom = progressAlongRoute(fromLat, fromLng, r.points);
      final pTo = progressAlongRoute(toLat, toLng, r.points);
      // هامش صغير: الوجهة يجب أن تكون «بعد» الراكب على نفس الاتجاه
      final towards = pTo >= pFrom - 0.02;

      candidates.add(NearbyLineMatch(
        lineName: r.lineName,
        direction: r.direction,
        distanceMeters: dFrom,
        route: r,
        destinationDistanceMeters: dTo,
        towardsDestination: towards,
      ));
    }

    // فضّل الاتجاه الصحيح أولاً، ثم الأقرب لنقطة الراكب
    candidates.sort((a, b) {
      if (a.towardsDestination != b.towardsDestination) {
        return a.towardsDestination ? -1 : 1;
      }
      final scoreA = a.distanceMeters +
          (a.destinationDistanceMeters ?? 0) * 0.35;
      final scoreB = b.distanceMeters +
          (b.destinationDistanceMeters ?? 0) * 0.35;
      return scoreA.compareTo(scoreB);
    });

    // إن وُجدت نتائج بالاتجاه الصحيح، استبعد العكسية
    final forward = candidates.where((c) => c.towardsDestination).toList();
    final pool = forward.isNotEmpty ? forward : candidates;

    return _dedupeBestByLine(pool, limit: limit);
  }

  List<NearbyLineMatch> _dedupeBestByLine(
    List<NearbyLineMatch> matches, {
    required int limit,
  }) {
    final bestByLine = <String, NearbyLineMatch>{};
    for (final m in matches) {
      final prev = bestByLine[m.lineName];
      if (prev == null) {
        bestByLine[m.lineName] = m;
        continue;
      }
      // فضّل towardsDestination ثم المسافة
      if (m.towardsDestination && !prev.towardsDestination) {
        bestByLine[m.lineName] = m;
        continue;
      }
      if (m.towardsDestination == prev.towardsDestination &&
          m.distanceMeters < prev.distanceMeters) {
        bestByLine[m.lineName] = m;
      }
    }

    final unique = bestByLine.values.toList()
      ..sort((a, b) {
        if (a.towardsDestination != b.towardsDestination) {
          return a.towardsDestination ? -1 : 1;
        }
        return a.distanceMeters.compareTo(b.distanceMeters);
      });

    if (unique.length > limit) return unique.sublist(0, limit);
    return unique;
  }
}
