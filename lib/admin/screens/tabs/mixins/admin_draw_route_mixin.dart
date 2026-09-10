import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../models/planned_route.dart';
import '../../../../models/route_point.dart';
import '../../../../services/route_plan/route_plan_geometry.dart';
import '../../../../services/route_plan_service.dart';
import '../../../widgets/admin_save_drawn_route_sheet.dart';

/// رسم مسار أدمن مع لصق حي على الشبكة الطرقية.
///
/// استراتيجية الرسم:
/// 1) تسجيل النقطة التي ضغط عليها المستخدم فوراً.
/// 2) إظهار المقطع بين آخر نقطتين فوراً كخط مؤقت.
/// 3) طلب Directions من Mapbox في الخلفية عند تفعيله.
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

  /// خط واحد للمسار الحي بالكامل.
  PolylineAnnotation? _drawLine;

  /// يمنع تداخل معالجة نقرات متعددة في القسم الحرج فقط
  /// (إضافة نقطة + مقطع مؤقت)، دون انتظار Directions.
  bool _tapLocked = false;

  /// جيل جلسة الرسم — يزيد عند start/cancel/clear.
  int _drawSession = 0;

  /// يزيد عند تغيّر بنية نقاط/مقاطع الرسم بما قد يبطل نتيجة Directions معلّقة.
  /// يمنع نتيجة Directions قديمة من الكتابة فوق مقطع أحدث.
  int _drawMutationSeq = 0;

  /// تسلسل إعادة رسم الخط — يمنع نتيجة redraw قديمة من الكتابة فوق أحدث.
  int _lineRedrawSeq = 0;

  /// يمنع تداخل عمليات create/delete الأصلية على الـ Polyline.
  bool _lineRedrawBusy = false;

  /// طلب redraw أحدث أثناء انشغال العملية الحالية.
  bool _lineRedrawQueued = false;

  /// يكتمل عند انتهاء دورة redraw الحالية (لـ clear/cancel).
  Completer<void>? _lineRedrawDone;

  /// جيل المسح البصري — يمنع clear قديماً من حذف خط جلسة أحدث.
  int _visualClearGen = 0;

  /// يمنع تداخل عمليات Undo المتعددة السريعة.
  bool _undoBusy = false;

  /// تسلسل عمليات الخط الواحد (redraw / clear).
  bool _segmentOpBusy = false;
  Completer<void>? _segmentOpDone;

  // Live road routing is restored now that the rendering path is no longer
  // based on PolylineAnnotation updates.
  static const bool _liveDirectionsEnabled = true;

  // The live route is rendered through a GeoJSON source + LineLayer instead of
  // PolylineAnnotation. This keeps the growing route in the style renderer.
  static const bool _livePolylineEnabled = true;

  static const String _liveRouteSourceId = 'admin_draw_route_source';
  static const String _liveRouteLayerId = 'admin_draw_route_layer';

  // Serialize Directions requests so rapid taps cannot create many concurrent
  // route requests whose responses all compete for the native Mapbox layer.
  bool _directionsBusy = false;
  Completer<void>? _directionsDone;

  // Coalesce rapid final Polyline updates onto latest geometry.
  bool _finalCoalesceRunning = false;
  bool _finalCoalesceQueued = false;
  int _finalCoalesceEpoch = 0;
  int _finalCoalesceRunnerEpoch = 0;

  // Coalesce rapid temporary Polyline updates onto latest geometry.
  bool _tempCoalesceRunning = false;
  bool _tempCoalesceQueued = false;
  int _tempCoalesceEpoch = 0;
  int _tempCoalesceRunnerEpoch = 0;

  /// المسار المعروض فعلياً على الخريطة.
  List<RoutePoint> get _flattenedRoadPath {
    if (_roadSegments.isEmpty) {
      return List<RoutePoint>.from(_drawPoints);
    }

    final out = <RoutePoint>[];

    for (final seg in _roadSegments) {
      if (seg.isEmpty) continue;

      // Keep each segment small before rebuilding the growing live path.
      // This avoids repeatedly scanning dozens of Directions vertices per
      // segment while preserving a representative road shape.
      final geometry = seg.length > 20
          ? RoutePlanGeometry.sampleEvenly(seg, 20)
          : seg;

      if (out.isEmpty) {
        out.addAll(geometry);
      } else {
        final join = geometry.first;
        final prev = out.last;
        final d = _haversineMeters(
          prev.latitude,
          prev.longitude,
          join.latitude,
          join.longitude,
        );
        if (d <= 3.0) {
          out.addAll(geometry.skip(1));
        } else {
          out.addAll(geometry);
        }
      }
    }

    return out;
  }

  void _invalidateFinalCoalesce() {
    _finalCoalesceEpoch++;
    _finalCoalesceQueued = false;
  }

  void _invalidateTempCoalesce() {
    _tempCoalesceEpoch++;
    _tempCoalesceQueued = false;
  }

  Future<void> _beginDirectionsOp() async {
    while (_directionsBusy) {
      final pending = _directionsDone;
      if (pending != null) await pending.future;
    }
    _directionsBusy = true;
    _directionsDone = Completer<void>();
  }

  void _endDirectionsOp() {
    _directionsBusy = false;
    final done = _directionsDone;
    _directionsDone = null;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
  }

  void startDrawingRoute() {
    if (!mounted) return;

    _drawSession++;
    _drawMutationSeq++;
    _lineRedrawSeq++;
    _tapLocked = false;
    _invalidateFinalCoalesce();
    _invalidateTempCoalesce();

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
    _drawMutationSeq++;
    _lineRedrawSeq++;
    _tapLocked = false;
    _invalidateFinalCoalesce();
    _invalidateTempCoalesce();

    setState(() {
      isDrawingRoute = false;
      isSnappingSegment = false;
      _drawPoints.clear();
      _roadSegments.clear();
    });

    await _clearDrawVisuals();
  }

  Future<void> _beginSegmentOp() async {
    while (_segmentOpBusy) {
      final pending = _segmentOpDone;
      if (pending != null) await pending.future;
    }
    _segmentOpBusy = true;
    _segmentOpDone = Completer<void>();
  }

  void _endSegmentOp() {
    _segmentOpBusy = false;
    final done = _segmentOpDone;
    _segmentOpDone = null;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
  }

  Future<void> _clearDrawVisuals() async {
    final clearGen = ++_visualClearGen;
    _invalidateFinalCoalesce();
    _invalidateTempCoalesce();
    _lineRedrawQueued = false;

    await _beginSegmentOp();
    try {
      if (clearGen != _visualClearGen) return;

      _drawLine = null;

      final map = mapboxMap;
      if (map != null) {
        try {
          await map.style.setStyleSourceProperty(
            _liveRouteSourceId,
            'data',
            jsonEncode({
              'type': 'FeatureCollection',
              'features': const [],
            }),
          );
        } catch (_) {}
      }
    } finally {
      _endSegmentOp();
    }
  }

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

      if (_drawPoints.length < 2) {
        if (mounted) setState(() {});
        return;
      }

      from = _drawPoints[_drawPoints.length - 2];
      to = _drawPoints.last;

      segmentIndex = _roadSegments.length;
      _roadSegments.add([from, to]);
      await _redrawDrawLine(phase: 'temp');
      if (mounted) setState(() {});
    } catch (e) {
      MapUtils.log('draw tap: $e', tag: 'AdminDraw');
      if (mounted && _drawPoints.length >= 2) {
        final a = _drawPoints[_drawPoints.length - 2];
        final b = _drawPoints.last;
        if (_roadSegments.length < _drawPoints.length - 1) {
          _roadSegments.add([a, b]);
          await _redrawDrawLine(phase: 'temp-fallback');
        }
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
      _tapLocked = false;
      if (mounted) {
        setState(() => isSnappingSegment = false);
      }
    }

    if (segmentIndex == null || from == null || to == null) return;
    if (session != _drawSession) return;

    final idx = segmentIndex;
    final a = from;
    final b = to;
    final mutation = _drawMutationSeq;

    try {
      if (!_liveDirectionsEnabled) {
        if (idx < _roadSegments.length) {
          _roadSegments[idx] = [a, b];
          await _redrawDrawLine(phase: 'final-fallback');
          if (mounted) setState(() {});
        }
        return;
      }

      // Serialize only Directions. Taps remain independent and can continue
      // being accepted while an older segment is waiting for its route result.
      List<RoutePoint> road;
      await _beginDirectionsOp();
      try {
        road = await _drawRouteService.getDrivingPath(
          from: a,
          to: b,
          attachControlEndpoints: false,
        );
      } finally {
        _endDirectionsOp();
      }

      if (!mounted ||
          session != _drawSession ||
          mutation != _drawMutationSeq) {
        return;
      }
      if (idx >= _roadSegments.length) return;

      final List<RoutePoint> pinned;
      if (road.length >= 2) {
        pinned = List<RoutePoint>.from(road);
        if (idx > 0 &&
            idx - 1 < _roadSegments.length &&
            _roadSegments[idx - 1].isNotEmpty) {
          pinned[0] = _roadSegments[idx - 1].last;
        }
      } else {
        pinned = [a, b];
      }

      _roadSegments[idx] = pinned;
      await _redrawDrawLine(phase: 'final');
      if (mounted) setState(() {});
    } catch (e) {
      MapUtils.log('draw segment directions: $e', tag: 'AdminDraw');
      if (!mounted ||
          session != _drawSession ||
          mutation != _drawMutationSeq) {
        return;
      }
      if (idx < _roadSegments.length) {
        _roadSegments[idx] = [a, b];
        await _redrawDrawLine(phase: 'final-fallback');
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _ensureLiveRouteLayer() async {
    final map = mapboxMap;
    if (map == null) return;

    final style = map.style;
    try {
      await style.addSource(
        GeoJsonSource(
          id: _liveRouteSourceId,
          data: jsonEncode({
            'type': 'FeatureCollection',
            'features': const [],
          }),
        ),
      );
    } catch (_) {
      // Source already exists in the current style.
    }

    try {
      await style.addLayer(
        LineLayer(
          id: _liveRouteLayerId,
          sourceId: _liveRouteSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineColor: 0xFF7C3AED,
          lineWidth: 5.0,
        ),
      );
    } catch (_) {
      // Layer already exists in the current style.
    }
  }

  String _liveRouteGeoJson(List<RoutePoint> path) {
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': 'admin_draw_route',
          'properties': const <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in path) [p.longitude, p.latitude],
            ],
          },
        },
      ],
    });
  }

  /// إعادة رسم المسار الحي كخط واحد داخل GeoJSON source.
  ///
  /// Unlike PolylineAnnotation.update(), this keeps one style source and one
  /// line layer alive and only replaces the source data. The visible geometry
  /// is still bounded so the source never grows without limit.
  Future<void> _redrawDrawLine({
    int? tapId,
    int? segmentIndex,
    String phase = '',
  }) async {
    if (!mounted || !_livePolylineEnabled) return;

    if (phase == 'temp' || phase == 'temp-fallback') {
      _tempCoalesceQueued = true;
      if (_tempCoalesceRunning) return;
      _tempCoalesceRunning = true;
      final epoch = _tempCoalesceEpoch;
      _tempCoalesceRunnerEpoch = epoch;
      try {
        while (_tempCoalesceQueued && mounted && epoch == _tempCoalesceEpoch) {
          _tempCoalesceQueued = false;
          await _redrawDrawLine(
            tapId: tapId,
            segmentIndex: segmentIndex,
            phase: '_temp_coalesced',
          );
        }
      } finally {
        _tempCoalesceRunning = false;
      }
      return;
    }

    if (phase == 'final' || phase == 'final-fallback') {
      _invalidateTempCoalesce();
      _finalCoalesceQueued = true;
      if (_finalCoalesceRunning) return;
      _finalCoalesceRunning = true;
      final epoch = _finalCoalesceEpoch;
      _finalCoalesceRunnerEpoch = epoch;
      try {
        while (_finalCoalesceQueued && mounted && epoch == _finalCoalesceEpoch) {
          _finalCoalesceQueued = false;
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (!mounted || epoch != _finalCoalesceEpoch) break;
          await _redrawDrawLine(
            tapId: tapId,
            segmentIndex: segmentIndex,
            phase: '_final_coalesced',
          );
        }
      } finally {
        _finalCoalesceRunning = false;
      }
      return;
    }

    await _beginSegmentOp();
    try {
      final session = _drawSession;
      final clearGen = _visualClearGen;
      final rawPath = _flattenedRoadPath;
      final path = rawPath.length > 140
          ? RoutePlanGeometry.sampleByDistance(
              rawPath,
              stepMeters: 30,
              maxPoints: 140,
            )
          : List<RoutePoint>.from(rawPath);

      if (session != _drawSession || clearGen != _visualClearGen) return;
      if (path.length < 2) {
        final map = mapboxMap;
        if (map == null) return;
        await _ensureLiveRouteLayer();
        await map.style.setStyleSourceProperty(
          _liveRouteSourceId,
          'data',
          jsonEncode({
            'type': 'FeatureCollection',
            'features': const [],
          }),
        );
        return;
      }

      if (phase == '_temp_coalesced' &&
          _tempCoalesceRunnerEpoch != _tempCoalesceEpoch) {
        return;
      }
      if (phase == '_final_coalesced' &&
          _finalCoalesceRunnerEpoch != _finalCoalesceEpoch) {
        return;
      }

      final map = mapboxMap;
      if (map == null) return;
      await _ensureLiveRouteLayer();
      if (!mounted ||
          session != _drawSession ||
          clearGen != _visualClearGen) {
        return;
      }

      await map.style.setStyleSourceProperty(
        _liveRouteSourceId,
        'data',
        _liveRouteGeoJson(path),
      );
    } catch (e) {
      MapUtils.log('draw line source update: $e', tag: 'AdminDraw');
    } finally {
      _endSegmentOp();
    }
  }

  Future<void> undoLastDrawPoint() async {
    if (_drawPoints.isEmpty || isSnappingSegment || _undoBusy) return;

    _undoBusy = true;
    try {
      _drawMutationSeq++;
      _invalidateFinalCoalesce();
      _invalidateTempCoalesce();

      _drawPoints.removeLast();

      if (_roadSegments.isNotEmpty) {
        _roadSegments.removeLast();
      }

      await _redrawDrawLine(phase: 'undo');

      if (mounted) {
        setState(() {});
      }
    } finally {
      _undoBusy = false;
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
    _drawMutationSeq++;
    _lineRedrawSeq++;
    _visualClearGen++;
    _lineRedrawQueued = false;
    _invalidateFinalCoalesce();
    _invalidateTempCoalesce();
    _tapLocked = false;
    _drawPoints.clear();
    _roadSegments.clear();
    _drawLine = null;
    _segmentOpBusy = false;
    _segmentOpDone = null;
    _directionsBusy = false;
    _directionsDone = null;

    isDrawingRoute = false;
    isSnappingSegment = false;
  }
}
