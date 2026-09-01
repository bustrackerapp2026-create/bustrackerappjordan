import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../models/planned_route.dart';
import '../../../../models/route_point.dart';
import '../../../../services/route_plan_service.dart';
import '../../../widgets/admin_save_drawn_route_sheet.dart';

/// رسم مسار أدمن مع لصق حي على الشبكة الطرقية.
///
/// استراتيجية الرسم:
/// 1) تسجيل النقطة التي ضغط عليها المستخدم فوراً.
/// 2) إظهار المقطع بين آخر نقطتين فوراً كخط مؤقت.
/// 3) طلب Directions من Mapbox في الخلفية.
/// 4) استبدال الخط المؤقت بالمسار الحقيقي عند نجاح Directions.
/// 5) إذا فشل الطلب، يبقى المقطع المباشر بدلاً من اختفائه.
///
/// بهذه الطريقة لا ينتظر الرسم استجابة الشبكة حتى يظهر أول مقطع.
mixin AdminDrawRouteMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _drawRouteService = RoutePlanService();

  bool isDrawingRoute = false;
  bool isSnappingSegment = false;

  final List<RoutePoint> _drawPoints = [];
  final List<List<RoutePoint>> _roadSegments = [];

  PolylineAnnotation? _drawLine;
  final List<PointAnnotation> _drawPointMarkers = [];

  /// يمنع تداخل معالجة نقرات متعددة في القسم الحرج فقط
  /// (إضافة نقطة + مقطع مؤقت)، دون انتظار Directions.
  bool _tapLocked = false;

  /// جيل جلسة الرسم — يزيد عند start/cancel/clear.
  int _drawSession = 0;

  /// تسلسل إعادة رسم الخط — يمنع نتيجة redraw قديمة من الكتابة فوق أحدث.
  int _lineRedrawSeq = 0;

  /// المسار المعروض فعلياً على الخريطة.
  ///
  /// إذا لم توجد مقاطع طرق محسوبة بعد، نعرض نقاط التحكم نفسها.
  /// أما بعد إنشاء المقاطع، فنستخدم المقاطع مع إزالة نقطة الالتقاء
  /// المكررة بين كل مقطعين.
  List<RoutePoint> get _flattenedRoadPath {
    if (_roadSegments.isEmpty) {
      return List<RoutePoint>.from(_drawPoints);
    }

    final out = <RoutePoint>[];

    for (final seg in _roadSegments) {
      if (seg.isEmpty) continue;

      if (out.isEmpty) {
        out.addAll(seg);
      } else {
        out.addAll(seg.skip(1));
      }
    }

    return out;
  }

  void startDrawingRoute() {
    if (!mounted) return;

    _drawSession++;
    _lineRedrawSeq++;
    _tapLocked = false;

    setState(() {
      isDrawingRoute = true;
      isSnappingSegment = false;
      _drawPoints.clear();
      _roadSegments.clear();
    });

    unawaited(_clearDrawVisuals());

    MapUtils.showSnackBar(
      context,
      'وضع الرسم: انقر على الخريطة لإضافة نقاط المسار',
    );
  }

  Future<void> cancelDrawingRoute() async {
    if (!mounted) return;

    _drawSession++;
    _lineRedrawSeq++;
    _tapLocked = false;

    setState(() {
      isDrawingRoute = false;
      isSnappingSegment = false;
      _drawPoints.clear();
      _roadSegments.clear();
    });

    await _clearDrawVisuals();
  }

  Future<void> _clearDrawVisuals() async {
    if (_drawLine != null && polylineAnnotationManager != null) {
      try {
        await polylineAnnotationManager!.delete(_drawLine!);
      } catch (_) {}
    }

    _drawLine = null;

    for (final marker in _drawPointMarkers) {
      try {
        await pointAnnotationManager?.delete(marker);
      } catch (_) {}
    }

    _drawPointMarkers.clear();
  }

  /// إضافة نقطة إلى المسار.
  ///
  /// الإصلاح الأساسي هنا:
  ///
  /// قبل انتظار Directions، نضيف مقطعاً مؤقتاً [from, to]
  /// ونرسمه فوراً.
  ///
  /// بعد وصول نتيجة Directions:
  /// - إذا نجحت: نستبدل المقطع المؤقت بالمسار الحقيقي.
  /// - إذا فشلت: نبقي المقطع المباشر.
  Future<void> onDrawRouteMapTap(Point point) async {
    if (!isDrawingRoute || !mounted || _tapLocked) return;

    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();
    final raw = RoutePoint(latitude: lat, longitude: lng);

    _tapLocked = true;
    setState(() => isSnappingSegment = true);

    final session = _drawSession;
    int? segmentIndex;
    RoutePoint? from;
    RoutePoint? to;

    try {
      // لا Map Matching لنقطة منفردة — يعيد النقطة كما هي.
      final snapped = await _drawRouteService.snapPointToRoad(raw);
      if (!mounted || session != _drawSession) return;

      if (_drawPoints.isNotEmpty) {
        final last = _drawPoints.last;
        final distance = _haversineMeters(
          last.latitude,
          last.longitude,
          snapped.latitude,
          snapped.longitude,
        );
        if (distance < 15) {
          MapUtils.showSnackBar(context, 'النقطة قريبة جداً من السابقة');
          return;
        }
      }

      _drawPoints.add(snapped);

      if (pointAnnotationManager != null) {
        try {
          final marker = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(snapped.longitude, snapped.latitude),
              ),
              iconSize: 0.6,
            ),
          );
          if (session != _drawSession) return;
          _drawPointMarkers.add(marker);
        } catch (e) {
          MapUtils.log('draw point marker: $e', tag: 'AdminDraw');
        }
      }

      // النقطة الأولى فقط — لا مقطع بعد.
      if (_drawPoints.length < 2) {
        await _redrawDrawLine();
        if (mounted) setState(() {});
        return;
      }

      from = _drawPoints[_drawPoints.length - 2];
      to = _drawPoints.last;

      // مرحلة 1: مقطع مؤقت فوري (لا ينتظر الشبكة).
      segmentIndex = _roadSegments.length;
      _roadSegments.add([from, to]);
      await _redrawDrawLine();
      if (mounted) setState(() {});
    } catch (e) {
      MapUtils.log('draw tap: $e', tag: 'AdminDraw');
      if (mounted && _drawPoints.length >= 2) {
        final a = _drawPoints[_drawPoints.length - 2];
        final b = _drawPoints.last;
        if (_roadSegments.length < _drawPoints.length - 1) {
          _roadSegments.add([a, b]);
        }
        await _redrawDrawLine();
        MapUtils.showSnackBar(
          context,
          'تمت إضافة النقطة، لكن تعذر تحسين المقطع بالطريق',
          isError: true,
        );
        setState(() {});
      } else if (mounted) {
        MapUtils.showSnackBar(context, 'تعذر إضافة النقطة', isError: true);
      }
    } finally {
      // حرر القفل فوراً بعد الرسم المؤقت حتى لا تُحجب النقطة التالية
      // أثناء انتظار Directions (سبب تأخر ظهور 1→2 ثم ظهور المسار من 3).
      _tapLocked = false;
      if (mounted) {
        setState(() => isSnappingSegment = false);
      }
    }

    // مرحلة 2: Directions في الخلفية مع حماية الجيل/الفهرس.
    if (segmentIndex == null || from == null || to == null) return;
    if (session != _drawSession) return;

    final idx = segmentIndex;
    final a = from;
    final b = to;

    try {
      final road = await _drawRouteService.getDrivingPath(from: a, to: b);
      if (!mounted || session != _drawSession) return;
      if (idx >= _roadSegments.length) return;

      _roadSegments[idx] = road.length >= 2 ? road : [a, b];
      await _redrawDrawLine();
      if (mounted) setState(() {});
    } catch (e) {
      MapUtils.log('draw segment directions: $e', tag: 'AdminDraw');
      if (!mounted || session != _drawSession) return;
      if (idx < _roadSegments.length) {
        _roadSegments[idx] = [a, b];
        await _redrawDrawLine();
        if (mounted) setState(() {});
      }
    }
  }

  /// إعادة رسم خط المسار الحالي.
  Future<void> _redrawDrawLine() async {
    if (!mounted) return;

    final seq = ++_lineRedrawSeq;
    final path = _flattenedRoadPath;
    final manager = polylineAnnotationManager;

    if (path.length < 2 || manager == null) {
      final old = _drawLine;
      _drawLine = null;
      if (old != null) {
        try {
          await manager?.delete(old);
        } catch (_) {}
      }
      return;
    }

    final coords = <Position>[
      for (final point in path) Position(point.longitude, point.latitude),
    ];
    final geometry = LineString(coordinates: coords);

    // حذف ثم إنشاء من جديد بدل update فقط:
    // update على أول مقطع غالباً لا يظهر الخط في mapbox_maps_flutter
    // حتى تُنشأ annotation لاحقة — وهذا يفسر اختفاء 1→2 وظهور المسار من 3.
    final previous = _drawLine;
    _drawLine = null;
    if (previous != null) {
      try {
        await manager.delete(previous);
      } catch (_) {}
    }

    // طلب أحدث؟ تجاهل هذه النتيجة.
    if (seq != _lineRedrawSeq || !mounted) return;

    try {
      final created = await manager.create(
        PolylineAnnotationOptions(
          geometry: geometry,
          lineColor: 0xFF7C3AED,
          lineWidth: 5.0,
        ),
      );
      if (seq != _lineRedrawSeq) {
        // رسم أحدث حلّ محلنا — احذف ما أنشأناه لتجنب خطوط يتيمة.
        try {
          await manager.delete(created);
        } catch (_) {}
        return;
      }
      _drawLine = created;
    } catch (e) {
      MapUtils.log('draw line: $e', tag: 'AdminDraw');
    }
  }

  /// التراجع عن آخر نقطة.
  Future<void> undoLastDrawPoint() async {
    if (_drawPoints.isEmpty || isSnappingSegment) return;

    _drawPoints.removeLast();

    if (_roadSegments.isNotEmpty) {
      _roadSegments.removeLast();
    }

    if (_drawPointMarkers.isNotEmpty) {
      final lastMarker = _drawPointMarkers.removeLast();

      try {
        await pointAnnotationManager?.delete(
          lastMarker,
        );
      } catch (_) {}
    }

    await _redrawDrawLine();

    if (mounted) {
      setState(() {});
    }
  }

  double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;

    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return earthRadius *
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );
  }

  double _rad(double degrees) {
    return degrees * math.pi / 180;
  }

  String _friendlySaveError(Object error) {
    final message = error.toString();

    if (message.contains('permission') || message.contains('PERMISSION')) {
      return 'رفض الصلاحيات على plannedRoutes — انشر firestore.rules ثم أعد المحاولة.';
    }

    return message;
  }

  Future<void> finishAndSaveDrawnRoute() async {
    if (!mounted || isSnappingSegment) return;

    if (_drawPoints.length < 2) {
      MapUtils.showSnackBar(
        context,
        'أضف نقطتين على الأقل',
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final adminId = auth.userId;

    if (adminId == null) {
      MapUtils.showSnackBar(
        context,
        'يجب تسجيل الدخول كأدمن قبل الحفظ',
        isError: true,
      );
      return;
    }

    final result = await showModalBottomSheet<
        ({
          String name,
          RouteDirection dir,
          List<String> aliases,
          String? notes,
          String start,
          String? middle,
          String end,
        })>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SaveDrawnRouteSheet(
        pointCount: _drawPoints.length,
        roadPointCount: _flattenedRoadPath.length,
      ),
    );

    if (result == null || !mounted) return;

    try {
      MapUtils.showSnackBar(
        context,
        'جاري تحسين المسار على الشوارع والجسور ثم الحفظ…',
      );

      final control = List<RoutePoint>.from(
        _drawPoints,
      );

      final saved = await _drawRouteService.saveAdminDrawnRoute(
        adminId: adminId,
        lineName: result.name,
        direction: result.dir,
        points: control,
        aliases: result.aliases,
        notes: result.notes,
        lineStart: result.start,
        lineMiddle: result.middle,
        lineEnd: result.end,
        alreadySnapped: false,
      );

      if (!mounted) return;

      setState(() {
        isDrawingRoute = false;
        isSnappingSegment = false;
        _drawPoints.clear();
        _roadSegments.clear();
      });

      await _clearDrawVisuals();

      if (!mounted) return;

      final km = ((saved.distanceMeters ?? 0) / 1000).toStringAsFixed(1);

      MapUtils.showSnackBar(
        context,
        '✅ تم اعتماد مسار ${result.dir.labelAr} «${result.name}» '
        '($km كم · ${saved.points.length} نقطة شارع) للجميع',
      );
    } catch (e) {
      MapUtils.log(
        'save drawn route: $e',
        tag: 'AdminDraw',
      );

      if (mounted) {
        MapUtils.showSnackBar(
          context,
          '❌ ${_friendlySaveError(e)}',
          isError: true,
        );
      }
    }
  }

  int get drawPointCount => _drawPoints.length;

  void disposeAdminDrawRoute() {
    _drawSession++;
    _lineRedrawSeq++;
    _tapLocked = false;
    _drawPoints.clear();
    _roadSegments.clear();
    _drawLine = null;
    _drawPointMarkers.clear();

    isDrawingRoute = false;
    isSnappingSegment = false;
  }
}
