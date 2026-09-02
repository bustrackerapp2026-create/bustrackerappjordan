import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/route_point.dart';
import 'route_plan_geometry.dart';

/// طلبات Mapbox Matching / Directions لبناء مسارات محاذية لشبكة الطرق.
///
/// الاستراتيجية:
/// 1) نقاط التحكم الخام تبقى مرتبة كما أدخلها المستخدم.
/// 2) لا يتم استخدام Map Matching لنقطة واحدة.
/// 3) Directions يستخدم نقاطًا حقيقية فقط.
/// 4) Map Matching يستخدم فقط مع نافذة تحتوي على نقطتين حقيقيتين
///    أو أكثر.
/// 5) عند فشل أي خدمة خارجية، نستخدم fallback آمن بدل اختراع
///    إحداثيات جديدة.
/// 6) لا يتم تغيير ترتيب نقاط المسار من خلال عمليات الـ snapping.
class RoutePlanMapbox {
  RoutePlanMapbox._();

  static final RoutePlanMapbox instance = RoutePlanMapbox._();

  /// نصف قطر اللصق داخل Map Matching للنقاط الداخلية.
  static const double pointSnapRadiusM = 40;

  /// نصف قطر أوسع عند أطراف نافذة الـ Matching.
  static const double pointSnapRadiusWideM = 75;

  /// الحد الآمن لعدد النقاط في طلب Matching.
  static const int _matchWindow = 48;

  /// عدد نقاط Directions في النافذة الواحدة.
  static const int _directionsWindow = 10;

  /// أقل مسافة نعتبر عندها نقطتين مختلفتين فعليًا.
  static const double _minimumUsefulDistanceM = 2;

  String? get _mapboxToken {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

    if (token.isEmpty || token == 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') {
      return null;
    }

    return token;
  }

  Future<String?> _httpGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 16),
  }) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(uri);

      final response = await request.close().timeout(timeout);

      if (response.statusCode != HttpStatus.ok) {
        if (kDebugMode) {
          debugPrint(
            'mapbox HTTP ${response.statusCode} → ${uri.path}',
          );
        }

        return null;
      }

      return await response.transform(utf8.decoder).join();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('mapbox HTTP error: $e');
      }

      return null;
    } finally {
      client.close(force: true);
    }
  }

  String _coord(RoutePoint point) {
    return '${point.longitude.toStringAsFixed(6)},'
        '${point.latitude.toStringAsFixed(6)}';
  }

  /// لصق نقطة واحدة على الطريق.
  ///
  /// مهم:
  /// Mapbox Map Matching v5 مخصص لمسار/trace متعدد النقاط.
  ///
  /// لا نقوم هنا:
  /// - بإنشاء نقطة ثانية اصطناعية.
  /// - بإضافة dLng.
  /// - بإرسال طلب Matching لنقطة واحدة.
  ///
  /// النقطة المعزولة تعاد كما هي.
  ///
  /// محاذاة الطريق الحقيقية تتم لاحقًا عبر:
  /// - Directions بين نقطتين حقيقيتين.
  /// - snapToRoads() عند وجود عدة نقاط.
  Future<RoutePoint> snapPointToRoad(
    RoutePoint point,
  ) async {
    return point;
  }

  /// بناء مسار قيادة بين نقطتين حقيقيتين.
  ///
  /// لا يوجد هنا أي إحداثي اصطناعي.
  Future<List<RoutePoint>> getDrivingPath({
    required RoutePoint from,
    required RoutePoint to,
    bool snapEndpoints = true,
    /// عند false: تُعاد هندسة Directions على الطريق دون فرض
    /// نقاط التحكم كأطراف (مناسب للرسم الحي؛ Markers منفصلة).
    bool attachControlEndpoints = true,
  }) async {
    final token = _mapboxToken;

    if (token == null) {
      return [from, to];
    }

    var a = from;
    var b = to;

    if (snapEndpoints) {
      // snapPointToRoad لا يرسل Matching لنقطة واحدة.
      final snapped = await Future.wait([
        snapPointToRoad(from),
        snapPointToRoad(to),
      ]);

      a = snapped[0];
      b = snapped[1];
    }

    final distance = RoutePlanGeometry.distanceMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );

    if (distance < 10) {
      return [a, b];
    }

    final path = await _directionsRequest(
      [a, b],
      token,
    );

    if (path.length < 2) {
      return [a, b];
    }

    if (!attachControlEndpoints) {
      // الرسم الحي: ابقَ على هندسة الطريق فقط.
      return path;
    }

    return RoutePlanGeometry.stitchEndpoints(
      path,
      a,
      b,
    );
  }

  /// طلب Mapbox Directions لمجموعة نقاط حقيقية.
  Future<List<RoutePoint>> _directionsRequest(
    List<RoutePoint> points,
    String token,
  ) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    final validPoints = _removeNearDuplicates(
      points,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (validPoints.length < 2) {
      return List<RoutePoint>.of(points);
    }

    final coords = validPoints.map(_coord).join(';');

    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/'
      'mapbox/driving/$coords'
      '?geometries=geojson'
      '&overview=full'
      '&steps=false'
      '&continue_straight=true'
      '&alternatives=false'
      '&exclude=ferry'
      '&access_token=$token',
    );

    final body = await _httpGet(
      uri,
      timeout: Duration(
        seconds: 10 + validPoints.length,
      ),
    );

    if (body == null) {
      return const [];
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      final code = data['code']?.toString();

      if (code != null && code != 'Ok') {
        if (kDebugMode) {
          debugPrint(
            'directions code=$code',
          );
        }

        return const [];
      }

      final routes = data['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) {
        return const [];
      }

      final firstRoute = routes.first as Map<String, dynamic>;

      final geometry = firstRoute['geometry'] as Map<String, dynamic>?;

      if (geometry == null) {
        return const [];
      }

      return RoutePlanGeometry.parseGeoJsonLine(
        geometry,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'directions parse: $e',
        );
      }

      return const [];
    }
  }

  /// بناء مسار كامل عبر مجموعة نقاط تحكم.
  ///
  /// [preserveWaypoints]: عند true لا يُطبَّق sampleByDistance (مناسب
  /// لنقاط الأدمن اليدوية عند التقاطعات). الافتراضي false لمسارات GPS الكثيفة.
  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints, {
    bool snapWaypoints = true,
    bool preserveWaypoints = false,
  }) async {
    if (waypoints.length < 2) {
      return List<RoutePoint>.of(waypoints);
    }

    final token = _mapboxToken;

    if (token == null) {
      return List<RoutePoint>.of(waypoints);
    }

    List<RoutePoint> points;
    if (preserveWaypoints) {
      // نقاط تحكم الأدمن: أبقِ كل النقاط بعد إزالة التكرارات القريبة فقط.
      points = List<RoutePoint>.of(waypoints);
    } else {
      points = RoutePlanGeometry.sampleByDistance(
        waypoints,
        stepMeters: 120,
        maxPoints: 36,
      );
    }

    points = _removeNearDuplicates(
      points,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (points.length < 2) {
      return List<RoutePoint>.of(waypoints);
    }

    if (snapWaypoints) {
      points = await _snapWaypointsBatched(
        points,
      );

      points = RoutePlanGeometry.dedupeNear(
        points,
        minMeters: 12,
      );

      if (points.length < 2) {
        return List<RoutePoint>.of(waypoints);
      }
    }

    final driven = await _driveInChunks(
      points,
      token,
    );

    if (driven.length < 2) {
      return await snapToRoads(
        waypoints,
        minSpacingMeters: 15,
      );
    }

    final polished = await snapToRoads(
      driven,
      minSpacingMeters: 12,
    );

    final cleaned = RoutePlanGeometry.removeSpikes(
      polished.length >= 2 ? polished : driven,
      maxJumpMeters: 160,
    );

    return RoutePlanGeometry.simplifyPoints(
      cleaned,
      minDistanceMeters: 7,
    );
  }

  Future<List<RoutePoint>> _snapWaypointsBatched(
    List<RoutePoint> points,
  ) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    final cleaned = _removeNearDuplicates(
      points,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (cleaned.length < 2) {
      return List<RoutePoint>.of(points);
    }

    return List<RoutePoint>.of(cleaned);
  }

  Future<List<RoutePoint>> _driveInChunks(
    List<RoutePoint> points,
    String token,
  ) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    if (points.length <= _directionsWindow) {
      final one = await _directionsRequest(
        points,
        token,
      );

      return one.length >= 2 ? one : List<RoutePoint>.of(points);
    }

    var output = <RoutePoint>[];

    final step = _directionsWindow - 1;

    for (var start = 0; start < points.length - 1; start += step) {
      final end = math.min(
        start + _directionsWindow,
        points.length,
      );

      final window = points.sublist(start, end);

      final segment = await _directionsRequest(
        window,
        token,
      );

      final piece = segment.length >= 2
          ? segment
          : List<RoutePoint>.of(window);

      if (output.isEmpty) {
        output = List<RoutePoint>.of(piece);
      } else {
        output = RoutePlanGeometry.mergePaths(
          output,
          piece,
        );
      }
    }

    return output.length >= 2 ? output : List<RoutePoint>.of(points);
  }

  Future<List<RoutePoint>> snapToRoads(
    List<RoutePoint> points, {
    double minSpacingMeters = 20,
  }) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    final token = _mapboxToken;

    if (token == null) {
      return List<RoutePoint>.of(points);
    }

    final cleaned = _removeNearDuplicates(
      points,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (cleaned.length < 2) {
      return List<RoutePoint>.of(points);
    }

    final matched = await _matchWindowRequest(
      cleaned,
      token,
    );

    if (matched.length < 2) {
      return List<RoutePoint>.of(cleaned);
    }

    return _removeNearDuplicates(
      matched,
      minDistanceMeters: minSpacingMeters,
    );
  }

  /// محاذاة مسار من نقاط تحكم (رسم أدمن يدوي).
  /// يحافظ على نقاط التحكم؛ لا يُسقِطها بـ sampleByDistance كل 120م.
  Future<List<RoutePoint>> buildRoadAlignedRoute(
    List<RoutePoint> controlPoints,
  ) async {
    if (controlPoints.length < 2) {
      return List<RoutePoint>.of(controlPoints);
    }

    return getDrivingPathThrough(
      controlPoints,
      snapWaypoints: true,
      preserveWaypoints: true,
    );
  }

  Future<List<RoutePoint>> _matchWindowRequest(
    List<RoutePoint> points,
    String token,
  ) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    if (points.length <= _matchWindow) {
      return await _matchOnce(points, token);
    }

    var output = <RoutePoint>[];
    final step = _matchWindow - 1;

    for (var start = 0; start < points.length - 1; start += step) {
      final end = math.min(start + _matchWindow, points.length);
      final window = points.sublist(start, end);
      final segment = await _matchOnce(window, token);
      final piece = segment.length >= 2
          ? segment
          : List<RoutePoint>.of(window);

      if (output.isEmpty) {
        output = List<RoutePoint>.of(piece);
      } else {
        output = RoutePlanGeometry.mergePaths(output, piece);
      }
    }

    return output.length >= 2 ? output : List<RoutePoint>.of(points);
  }

  Future<List<RoutePoint>> _matchOnce(
    List<RoutePoint> points,
    String token,
  ) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    final coords = points.map(_coord).join(';');
    final radiuses = List.filled(points.length, pointSnapRadiusM.toStringAsFixed(0))
        .join(';');

    final uri = Uri.parse(
      'https://api.mapbox.com/matching/v5/'
      'mapbox/driving/$coords'
      '?geometries=geojson'
      '&overview=full'
      '&tidy=true'
      '&radiuses=$radiuses'
      '&access_token=$token',
    );

    final body = await _httpGet(uri);

    if (body == null) {
      return const [];
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final code = data['code']?.toString();

      if (code != null && code != 'Ok') {
        return const [];
      }

      final matchings = data['matchings'] as List<dynamic>?;

      if (matchings == null || matchings.isEmpty) {
        return const [];
      }

      final first = matchings.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;

      if (geometry == null) {
        return const [];
      }

      return RoutePlanGeometry.parseGeoJsonLine(geometry);
    } catch (_) {
      return const [];
    }
  }

  List<RoutePoint> _removeNearDuplicates(
    List<RoutePoint> points, {
    required double minDistanceMeters,
  }) {
    if (points.isEmpty) {
      return const [];
    }

    final output = <RoutePoint>[points.first];

    for (var i = 1; i < points.length; i++) {
      final last = output.last;
      final current = points[i];

      final distance = RoutePlanGeometry.distanceMeters(
        last.latitude,
        last.longitude,
        current.latitude,
        current.longitude,
      );

      if (distance >= minDistanceMeters) {
        output.add(current);
      }
    }

    if (points.length >= 2) {
      final lastOriginal = points.last;
      final lastKept = output.last;

      final distance = RoutePlanGeometry.distanceMeters(
        lastKept.latitude,
        lastKept.longitude,
        lastOriginal.latitude,
        lastOriginal.longitude,
      );

      if (distance >= minDistanceMeters) {
        output.add(lastOriginal);
      }
    }

    return output;
  }
}
