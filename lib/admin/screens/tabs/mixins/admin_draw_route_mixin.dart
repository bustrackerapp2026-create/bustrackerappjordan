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

  /// خط واحد للمسار الحي بالكامل.
  PolylineAnnotation? _drawLine;

  /// نقاط الرسم كدوائر (بدون PointAnnotation/icon الافتراضي).
  CircleAnnotationManager? _drawCircleManager;
  final List<CircleAnnotation> _drawPointMarkers = [];

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

  /// يمنع تداخل استدعاءات Undo المتعددة السريعة.
  bool _undoBusy = false;

  /// تسلسل عمليات الخط الواحد (redraw / clear).
  bool _segmentOpBusy = false;
  Completer<void>? _segmentOpDone;

  // --- PERF instrumentation (temporary, diagnosis only) ---
  int _perfTapId = 0;
  int _perfRedrawId = 0;

  /// المسار المعروض فعلياً على الخريطة.
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
        final join = seg.first;
        final prev = out.last;
        final d = _haversineMeters(
          prev.latitude,
          prev.longitude,
          join.latitude,
          join.longitude,
        );
        if (d <= 3.0) {
          out.addAll(seg.skip(1));
        } else {
          out.addAll(seg);
        }
      }
    }

    return out;
  }

  Future<void> _ensureDrawCircleManager() async {
    if (_drawCircleManager != null || mapboxMap == null) return;
    try {
      _drawCircleManager =
          await mapboxMap!.annotations.createCircleAnnotationManager();
    } catch (e) {
      MapUtils.log('draw circle manager: $e', tag: 'AdminDraw');
    }
  }

  void startDrawingRoute() {
    if (!mounted) return;

    _drawSession++;
    _drawMutationSeq++;
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
    _drawMutationSeq++;
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
    _lineRedrawQueued = false;

    await _beginSegmentOp();
    try {
      if (clearGen != _visualClearGen) return;

      final lineToDelete = _drawLine;
      final markersToDelete =
          List<CircleAnnotation>.from(_drawPointMarkers);
      _drawLine = null;
      _drawPointMarkers.clear();

      final polyManager = polylineAnnotationManager;
      if (lineToDelete != null && polyManager != null) {
        try {
          await polyManager.delete(lineToDelete);
        } catch (_) {}
      }

      for (final marker in markersToDelete) {
        try {
          await _drawCircleManager?.delete(marker);
        } catch (_) {}
      }
    } finally {
      _endSegmentOp();
    }
  }

  Future<void> onDrawRouteMapTap(Point point) async {
    if (!isDrawingRoute || !mounted || _tapLocked) return;

    final tapId = ++_perfTapId;
    final swTapTotal = Stopwatch()..start();
    MapUtils.log(
      'PERF|tapStart tapId=$tapId session=$_drawSession mutation=$_drawMutationSeq',
      tag: 'AdminDrawPerf',
    );

    // Outer finally guarantees PERF|tapEnd on every exit path
    // (first point, too-close, session stale, normal, error, etc.)
    try {

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
      final swSnap = Stopwatch()..start();
      final snapped = await _drawRouteService.snapPointToRoad(raw);
      swSnap.stop();
      MapUtils.log(
        'PERF|snap tapId=$tapId ms=${swSnap.elapsedMilliseconds}',
        tag: 'AdminDrawPerf',
      );
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

      final swCircle = Stopwatch()..start();
      try {
        await _ensureDrawCircleManager();
        final manager = _drawCircleManager;
        if (manager != null) {
          final marker = await manager.create(
            CircleAnnotationOptions(
              geometry: Point(
                coordinates: Position(snapped.longitude, snapped.latitude),
              ),
              circleRadius: 3.0,
              circleColor: 0xFF7C3AED,
              circleStrokeColor: 0xFFFFFFFF,
              circleStrokeWidth: 1.5,
              // مخفية بصرياً بالكامل؛ المراجع تبقى لـ Undo
              circleOpacity: 0.0,
              circleStrokeOpacity: 0.0,
            ),
          );
          if (session != _drawSession) {
            swCircle.stop();
            MapUtils.log(
              'PERF|circleCreate tapId=$tapId ms=${swCircle.elapsedMilliseconds} stale=true',
              tag: 'AdminDrawPerf',
            );
            return;
          }
          _drawPointMarkers.add(marker);
          swCircle.stop();
          MapUtils.log(
            'PERF|circleCreate tapId=$tapId ms=${swCircle.elapsedMilliseconds}',
            tag: 'AdminDrawPerf',
          );
        } else {
          swCircle.stop();
          MapUtils.log(
            'PERF|circleCreate tapId=$tapId ms=${swCircle.elapsedMilliseconds} manager=null',
            tag: 'AdminDrawPerf',
          );
        }
      } catch (e) {
        swCircle.stop();
        MapUtils.log(
          'PERF|circleCreate tapId=$tapId ms=${swCircle.elapsedMilliseconds} error=true',
          tag: 'AdminDrawPerf',
        );
        MapUtils.log('draw point marker: $e', tag: 'AdminDraw');
      }

      if (_drawPoints.length < 2) {
        if (mounted) setState(() {});
        return;
      }

      from = _drawPoints[_drawPoints.length - 2];
      to = _drawPoints.last;

      segmentIndex = _roadSegments.length;
      _roadSegments.add([from, to]);
      final swTempRedraw = Stopwatch()..start();
      await _redrawDrawLine(
        tapId: tapId,
        segmentIndex: segmentIndex,
        phase: 'temp',
      );
      swTempRedraw.stop();
      MapUtils.log(
        'PERF|tempRedrawDone tapId=$tapId seg=$segmentIndex ms=${swTempRedraw.elapsedMilliseconds}',
        tag: 'AdminDrawPerf',
      );
      if (mounted) setState(() {});
    } catch (e) {
      MapUtils.log('draw tap: $e', tag: 'AdminDraw');
      if (mounted && _drawPoints.length >= 2) {
        final a = _drawPoints[_drawPoints.length - 2];
        final b = _drawPoints.last;
        if (_roadSegments.length < _drawPoints.length - 1) {
          _roadSegments.add([a, b]);
          await _redrawDrawLine(
            tapId: tapId,
            segmentIndex: _roadSegments.length - 1,
            phase: 'temp-fallback',
          );
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
      MapUtils.log(
        'PERF|tapUnlocked tapId=$tapId elapsedMs=${swTapTotal.elapsedMilliseconds}',
        tag: 'AdminDrawPerf',
      );
    }

    if (segmentIndex == null || from == null || to == null) return;
    if (session != _drawSession) return;

    final idx = segmentIndex;
    final a = from;
    final b = to;
    final mutation = _drawMutationSeq;

    try {
      // الرسم الحي: هندسة الطريق فقط — بدون stitch إلى نقاط النقر
      final swDir = Stopwatch()..start();
      final road = await _drawRouteService.getDrivingPath(
        from: a,
        to: b,
        attachControlEndpoints: false,
        perfTapId: tapId,
        perfSegmentIndex: idx,
      );
      swDir.stop();
      MapUtils.log(
        'PERF|getDrivingPathDone tapId=$tapId seg=$idx '
        'ms=${swDir.elapsedMilliseconds} points=${road.length}',
        tag: 'AdminDrawPerf',
      );
      if (!mounted ||
          session != _drawSession ||
          mutation != _drawMutationSeq) {
        return;
      }
      if (idx >= _roadSegments.length) return;

      final List<RoutePoint> pinned;
      if (road.length >= 2) {
        pinned = List<RoutePoint>.from(road);
        // ربط أول نقطة بنهاية المقطع السابق فقط — لا تفرض b
        if (idx > 0 &&
            idx - 1 < _roadSegments.length &&
            _roadSegments[idx - 1].isNotEmpty) {
          pinned[0] = _roadSegments[idx - 1].last;
        }
      } else {
        pinned = [a, b];
      }

      _roadSegments[idx] = pinned;
      final swFinalRedraw = Stopwatch()..start();
      await _redrawDrawLine(
        tapId: tapId,
        segmentIndex: idx,
        phase: 'final',
      );
      swFinalRedraw.stop();
      MapUtils.log(
        'PERF|finalRedrawDone tapId=$tapId seg=$idx ms=${swFinalRedraw.elapsedMilliseconds}',
        tag: 'AdminDrawPerf',
      );
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
        await _redrawDrawLine(
          tapId: tapId,
          segmentIndex: idx,
          phase: 'final-fallback',
        );
        if (mounted) setState(() {});
      }
    }

    } finally {
      // Guarantees PERF|tapEnd for every path that passed the initial guard
      // (first point, too-close, session stale, normal completion, errors, etc.)
      swTapTotal.stop();
      MapUtils.log(
        'PERF|tapEnd tapId=$tapId totalMs=${swTapTotal.elapsedMilliseconds} '
        'session=$_drawSession mutation=$_drawMutationSeq',
        tag: 'AdminDrawPerf',
      );
    }
  }

  /// إعادة رسم المسار الحي كخط واحد من _flattenedRoadPath.
  Future<void> _redrawDrawLine({
    int? tapId,
    int? segmentIndex,
    String phase = '',
  }) async {
    if (!mounted) return;

    final redrawId = ++_perfRedrawId;
    final swTotal = Stopwatch()..start();
    final swWait = Stopwatch()..start();
    await _beginSegmentOp();
    swWait.stop();

    int pathN = 0;
    int posN = 0;
    int flatMs = 0;
    int posMs = 0;
    int geomMs = 0;
    int updateMs = 0;
    int createMs = 0;
    int deleteMs = 0;
    bool updateOk = false;
    bool usedFallback = false;

    try {
      final session = _drawSession;
      final clearGen = _visualClearGen;
      final manager = polylineAnnotationManager;
      if (manager == null) return;
      if (session != _drawSession || clearGen != _visualClearGen) return;

      final swFlat = Stopwatch()..start();
      final path = List<RoutePoint>.from(_flattenedRoadPath);
      swFlat.stop();
      flatMs = swFlat.elapsedMilliseconds;
      pathN = path.length;

      // أقل من نقطتين → احذف الخط الحالي فقط إن كان ما زال لنا
      if (path.length < 2) {
        final old = _drawLine;
        if (old != null &&
            session == _drawSession &&
            clearGen == _visualClearGen) {
          _drawLine = null;
          try {
            await manager.delete(old);
          } catch (_) {}
        }
        return;
      }

      final swPos = Stopwatch()..start();
      final coords = <Position>[
        for (final p in path) Position(p.longitude, p.latitude),
      ];
      swPos.stop();
      posMs = swPos.elapsedMilliseconds;
      posN = coords.length;

      final swGeom = Stopwatch()..start();
      final geometry = LineString(coordinates: coords);
      swGeom.stop();
      geomMs = swGeom.elapsedMilliseconds;

      // المسار السعيد: update فقط
      final existing = _drawLine;
      if (existing != null) {
        try {
          existing.geometry = geometry;
          final swUpdate = Stopwatch()..start();
          await manager.update(existing);
          swUpdate.stop();
          updateMs = swUpdate.elapsedMilliseconds;
          updateOk = true;
          // بعد await: لا نلمس شيئًا إن تغيّرت الجلسة/المسح
          if (session != _drawSession || clearGen != _visualClearGen) return;
          return;
        } catch (e) {
          MapUtils.log('draw line update fallback: $e', tag: 'AdminDraw');
          usedFallback = true;
          // لا نُفرّغ _drawLine هنا — قد يبقى صالحًا؛ نحاول create ثم نستبدل بحذر
        }
      }

      // fallback: create أولًا
      if (session != _drawSession || clearGen != _visualClearGen) return;

      PolylineAnnotation? created;
      try {
        final swCreate = Stopwatch()..start();
        created = await manager.create(
          PolylineAnnotationOptions(
            geometry: geometry,
            lineColor: 0xFF7C3AED,
            lineWidth: 5.0,
          ),
        );
        swCreate.stop();
        createMs = swCreate.elapsedMilliseconds;
        usedFallback = true;
      } catch (e) {
        MapUtils.log('draw line create: $e', tag: 'AdminDraw');
        return;
      }

      // بعد create: إن أصبحنا stale احذف المُنشأ فقط ولا تلمس _drawLine الحالي
      if (!mounted ||
          session != _drawSession ||
          clearGen != _visualClearGen) {
        try {
          final swDel = Stopwatch()..start();
          await manager.delete(created);
          swDel.stop();
          deleteMs = swDel.elapsedMilliseconds;
        } catch (_) {}
        return;
      }

      // ما زلنا أصحاب الجلسة: اعتمد المُنشأ ثم احذف السابق إن وُجد
      final previous = _drawLine;
      _drawLine = created;
      if (previous != null && !identical(previous, created)) {
        try {
          final swDel = Stopwatch()..start();
          await manager.delete(previous);
          swDel.stop();
          deleteMs = swDel.elapsedMilliseconds;
        } catch (_) {}
        // بعد delete: إن تغيّرت الجلسة لا نُعدّل _drawLine أكثر —
        // clear الأحدث إما مسح المرجع أو سيمسح عبر لقطته الخاصة
      }
    } finally {
      _endSegmentOp();
      swTotal.stop();
      MapUtils.log(
        'PERF|redraw redrawId=$redrawId tapId=$tapId seg=$segmentIndex phase=$phase '
        'waitMs=${swWait.elapsedMilliseconds} '
        'flatMs=$flatMs pathN=$pathN '
        'posMs=$posMs posN=$posN '
        'geomMs=$geomMs '
        'updateMs=$updateMs updateOk=$updateOk '
        'fallback=$usedFallback createMs=$createMs deleteMs=$deleteMs '
        'totalMs=${swTotal.elapsedMilliseconds} '
        'session=$_drawSession mutation=$_drawMutationSeq',
        tag: 'AdminDrawPerf',
      );
    }
  }

  Future<void> undoLastDrawPoint() async {
    if (_drawPoints.isEmpty || isSnappingSegment || _undoBusy) return;

    _undoBusy = true;
    try {
      _drawMutationSeq++;

      _drawPoints.removeLast();

      if (_roadSegments.isNotEmpty) {
        _roadSegments.removeLast();
      }

      if (_drawPointMarkers.isNotEmpty) {
        final lastMarker = _drawPointMarkers.removeLast();

        try {
          await _drawCircleManager?.delete(lastMarker);
        } catch (_) {}
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
    _tapLocked = false;
    _drawPoints.clear();
    _roadSegments.clear();
    _drawLine = null;
    _segmentOpBusy = false;
    _segmentOpDone = null;
    _drawPointMarkers.clear();
    _drawCircleManager = null;

    isDrawingRoute = false;
    isSnappingSegment = false;
  }
}
