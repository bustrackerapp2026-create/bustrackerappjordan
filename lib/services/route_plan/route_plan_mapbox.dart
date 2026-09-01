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
  }) async {
    final token = _mapboxToken;

    if (token == null) {
      return [from, to];
    }

    var a = from;
    var b = to;

    if (snapEndpoints) {
      // snapPointToRoad لا يرسل Matching لنقطة واحدة.
      //
      // أبقينا الاستدعاء للحفاظ على الـ API وسلوك الاستدعاءات
      // الخارجية، لكن النقاط تبقى حقيقية.
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

    // نقطتان متطابقتان أو شبه متطابقتين:
    // لا نرسل طلب Directions غير مفيد.
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
  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints, {
    bool snapWaypoints = true,
  }) async {
    if (waypoints.length < 2) {
      return List<RoutePoint>.of(waypoints);
    }

    final token = _mapboxToken;

    if (token == null) {
      return List<RoutePoint>.of(waypoints);
    }

    var points = RoutePlanGeometry.sampleByDistance(
      waypoints,
      stepMeters: 120,
      maxPoints: 36,
    );

    points = _removeNearDuplicates(
      points,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (points.length < 2) {
      return List<RoutePoint>.of(waypoints);
    }

    if (snapWaypoints) {
      // لا يوجد هنا Matching نقطة بنقطة.
      //
      // _snapWaypointsBatched يستخدم الآن نقطة التحكم
      // كما هي بدل اختراع نقطة ثانية.
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

    // Matching هنا مسموح لأنه يتم على مسار حقيقي
    // يحتوي على عدة نقاط.
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

  /// الحفاظ على ترتيب النقاط بدون استدعاء Matching
  /// لكل نقطة على حدة.
  ///
  /// هذه الدالة أصبحت آمنة من مشكلة:
  ///
  /// point → point + 0.000045
  ///
  /// ولا تنشئ أي إحداثيات اصطناعية.
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

    // لا نرسل Matching لكل waypoint منفرد.
    //
    // السبب:
    // Matching يحتاج trace حقيقيًا متعدد النقاط.
    //
    // محاذاة هذه النقاط تتم لاحقًا بواسطة Directions
    // ثم snapToRoads على المسار الناتج.
    return List<RoutePoint>.of(cleaned);
  }

  /// تشغيل Directions على نوافذ متداخلة.
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

    // نقطة واحدة مشتركة بين النوافذ.
    final step = _directionsWindow - 1;

    for (var start = 0; start < points.length - 1; start += step) {
      final end = math.min(
        start + _directionsWindow,
        points.length,
      );

      final chunk = points.sublist(start, end);

      if (chunk.length < 2) {
        continue;
      }

      var path = await _directionsRequest(
        chunk,
        token,
      );

      // fallback إلى أزواج حقيقية.
      if (path.length < 2) {
        path = await _drivePairs(
          chunk,
          token,
        );
      }

      // fallback أخير: نقاط chunk نفسها.
      if (path.length < 2) {
        path = List<RoutePoint>.of(chunk);
      }

      // حماية من مسار التفافي غير منطقي.
      final air = RoutePlanGeometry.distanceMeters(
        chunk.first.latitude,
        chunk.first.longitude,
        chunk.last.latitude,
        chunk.last.longitude,
      );

      final road = RoutePlanGeometry.totalDistanceMeters(
        path,
      );

      if (air > 80 && road > air * 4.5) {
        final pairs = await _drivePairs(
          chunk,
          token,
        );

        if (pairs.length >= 2) {
          final pairsDistance = RoutePlanGeometry.totalDistanceMeters(
            pairs,
          );

          if (pairsDistance < road) {
            path = pairs;
          }
        }
      }

      output = output.isEmpty
          ? path
          : RoutePlanGeometry.mergePaths(
              output,
              path,
              joinToleranceM: 30,
            );

      if (end >= points.length) {
        break;
      }
    }

    if (output.length < 2) {
      return List<RoutePoint>.of(points);
    }

    return RoutePlanGeometry.dedupeNear(
      output,
      minMeters: 4,
    );
  }

  /// Directions بين أزواج متتالية من نقاط حقيقية.
  Future<List<RoutePoint>> _drivePairs(
    List<RoutePoint> points,
    String token,
  ) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    var output = <RoutePoint>[];

    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];

      final distance = RoutePlanGeometry.distanceMeters(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );

      // لا نرسل زوجًا متطابقًا تقريبًا.
      if (distance < _minimumUsefulDistanceM) {
        if (output.isEmpty) {
          output.add(from);
        }

        continue;
      }

      final segment = await _directionsRequest(
        [from, to],
        token,
      );

      final use = segment.length >= 2
          ? segment
          : <RoutePoint>[
              from,
              to,
            ];

      output = output.isEmpty
          ? List<RoutePoint>.of(use)
          : RoutePlanGeometry.mergePaths(
              output,
              use,
              joinToleranceM: 20,
            );
    }

    return output;
  }

  /// Map Matching لمسار يحتوي على نقاط حقيقية متعددة.
  ///
  /// هذه الدالة لا تنشئ أي نقطة إضافية.
  Future<List<RoutePoint>> snapToRoads(
    List<RoutePoint> points, {
    double minSpacingMeters = 20,
  }) async {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    var simplified = RoutePlanGeometry.simplifyPoints(
      points,
      minDistanceMeters: minSpacingMeters,
    );

    simplified = _removeNearDuplicates(
      simplified,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (simplified.length < 2) {
      return simplified;
    }

    final token = _mapboxToken;

    if (token == null) {
      return simplified;
    }

    try {
      var output = <RoutePoint>[];

      final step = _matchWindow - 4;

      for (var start = 0; start < simplified.length; start += step) {
        final end = math.min(
          start + _matchWindow,
          simplified.length,
        );

        final chunk = simplified.sublist(start, end);

        if (chunk.length < 2) {
          continue;
        }

        // حماية إضافية:
        // لا نرسل Matching إذا أصبحت النافذة
        // فعليًا نقطة واحدة بعد إزالة التكرارات.
        final validChunk = _removeNearDuplicates(
          chunk,
          minDistanceMeters: _minimumUsefulDistanceM,
        );

        if (validChunk.length < 2) {
          continue;
        }

        final matched = await _matchWindowRequest(
          validChunk,
          token,
        );

        final use = matched.length >= 2 ? matched : validChunk;

        output = output.isEmpty
            ? List<RoutePoint>.of(use)
            : RoutePlanGeometry.mergePaths(
                output,
                use,
                joinToleranceM: 25,
              );

        if (end >= simplified.length) {
          break;
        }

        await Future<void>.delayed(
          const Duration(milliseconds: 30),
        );
      }

      if (output.length < 2) {
        return simplified;
      }

      final cleaned = RoutePlanGeometry.removeSpikes(
        output,
        maxJumpMeters: 150,
      );

      return RoutePlanGeometry.simplifyPoints(
        cleaned,
        minDistanceMeters: 7,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'snapToRoads: $e',
        );
      }

      return simplified;
    }
  }

  /// طلب Matching لنافذة متعددة النقاط.
  ///
  /// مهم:
  /// لا تستخدم هذه الدالة إلا عندما sample تحتوي
  /// على نقطتين حقيقيتين أو أكثر.
  Future<List<RoutePoint>> _matchWindowRequest(
    List<RoutePoint> sample,
    String token,
  ) async {
    final validSample = _removeNearDuplicates(
      sample,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (validSample.length < 2) {
      return const [];
    }

    final coords = validSample.map(_coord).join(';');

    // نصف قطر متدرج:
    // أوسع عند الأطراف، وأضيق في الوسط.
    final radiuses = <String>[];

    for (var i = 0; i < validSample.length; i++) {
      final isEdge = i == 0 || i == validSample.length - 1;

      final radius = isEdge ? pointSnapRadiusWideM : pointSnapRadiusM;

      radiuses.add(
        radius.toStringAsFixed(0),
      );
    }

    final uri = Uri.parse(
      'https://api.mapbox.com/matching/v5/'
      'mapbox/driving/$coords'
      '?geometries=geojson'
      '&overview=full'
      '&tidy=true'
      '&radiuses=${radiuses.join(';')}'
      '&gaps=ignore'
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
        if (kDebugMode) {
          debugPrint(
            'matching code=$code',
          );
        }

        return const [];
      }

      final matchings = data['matchings'] as List<dynamic>?;

      if (matchings == null || matchings.isEmpty) {
        return const [];
      }

      final snapped = <RoutePoint>[];

      for (final item in matchings) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final geometry = item['geometry'] as Map<String, dynamic>?;

        if (geometry == null) {
          continue;
        }

        final path = RoutePlanGeometry.parseGeoJsonLine(
          geometry,
        );

        if (path.isEmpty) {
          continue;
        }

        if (snapped.isEmpty) {
          snapped.addAll(path);
        } else {
          // تجنب تكرار نقطة الوصل.
          snapped.addAll(
            path.skip(1),
          );
        }
      }

      return snapped;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'matching parse: $e',
        );
      }

      return const [];
    }
  }

  /// بناء مسار كامل محاذٍ للطرق من نقاط التحكم الخام.
  Future<List<RoutePoint>> buildRoadAlignedRoute(
    List<RoutePoint> controlPoints,
  ) async {
    if (controlPoints.length < 2) {
      return List<RoutePoint>.of(
        controlPoints,
      );
    }

    final cleanedControlPoints = _removeNearDuplicates(
      controlPoints,
      minDistanceMeters: 8,
    );

    if (cleanedControlPoints.length < 2) {
      return List<RoutePoint>.of(
        controlPoints,
      );
    }

    // 1) تنظيف/أخذ عينات حسب المسافة.
    final prepared = RoutePlanGeometry.sampleByDistance(
      cleanedControlPoints,
      stepMeters: 110,
      maxPoints: 42,
    );

    final preparedClean = _removeNearDuplicates(
      prepared,
      minDistanceMeters: _minimumUsefulDistanceM,
    );

    if (preparedClean.length < 2) {
      return List<RoutePoint>.of(
        controlPoints,
      );
    }

    // 2) بناء مسار القيادة الحقيقي عبر النقاط.
    final viaDirections = await getDrivingPathThrough(
      preparedClean,
      snapWaypoints: true,
    );

    if (viaDirections.length >= 8) {
      final cleaned = RoutePlanGeometry.removeSpikes(
        viaDirections,
        maxJumpMeters: 150,
        maxTurnDegrees: 150,
      );

      return RoutePlanGeometry.simplifyPoints(
        cleaned,
        minDistanceMeters: 7,
      );
    }

    // 3) Fallback:
    // Matching مباشر على مسار متعدد النقاط.
    final matched = await snapToRoads(
      preparedClean,
      minSpacingMeters: 12,
    );

    if (matched.length >= 2) {
      return RoutePlanGeometry.removeSpikes(
        matched,
        maxJumpMeters: 150,
      );
    }

    // 4) آخر fallback:
    // النقاط الأصلية بدون تغيير ترتيبها.
    return RoutePlanGeometry.simplifyPoints(
      controlPoints,
      minDistanceMeters: 12,
    );
  }

  /// إزالة النقاط المتطابقة أو شديدة التقارب.
  ///
  /// تحافظ على ترتيب الإدخال.
  List<RoutePoint> _removeNearDuplicates(
    List<RoutePoint> points, {
    double minDistanceMeters = 2,
  }) {
    if (points.length < 2) {
      return List<RoutePoint>.of(points);
    }

    final output = <RoutePoint>[
      points.first,
    ];

    for (var i = 1; i < points.length; i++) {
      final current = points[i];
      final previous = output.last;

      final distance = RoutePlanGeometry.distanceMeters(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );

      if (distance >= minDistanceMeters) {
        output.add(current);
      }
    }

    // لا نحذف آخر نقطة إذا كانت هي نقطة النهاية
    // إلا إذا كانت مطابقة فعليًا للنقطة السابقة.
    if (output.length >= 2) {
      final lastOriginal = points.last;
      final lastOutput = output.last;

      final lastDistance = RoutePlanGeometry.distanceMeters(
        lastOutput.latitude,
        lastOutput.longitude,
        lastOriginal.latitude,
        lastOriginal.longitude,
      );

      if (lastDistance >= minDistanceMeters) {
        output.add(lastOriginal);
      }
    }

    return output;
  }
}
