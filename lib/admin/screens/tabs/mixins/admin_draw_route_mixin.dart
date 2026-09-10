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
import '../../../../services/route_plan/route_plan_geometry.dart';
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

      // Directions can still return up to 60 stored vertices per segment.
      // Do not flatten all of those into the growing live path on every tap;
      // keep a small representative geometry per segment first.
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

      final lineToDelete = _drawLine;
      _drawLine = null;

      final polyManager = polylineAnnotationManager;
      if (lineToDelete != null && polyManager != null) {
        try {
          await polyManager.delete(lineToDelete);
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

  /// إعادة رسم المسار الحي كخط واحد من _flattenedRoadPath.
  Future<void> _redrawDrawLine({
    int? tapId,
    int? segmentIndex,
    String phase = '',
  }) async {
    if (!mounted) return;

    // Temporary redraws: keep only the newest geometry while a native write is running.
    if (phase == 'temp' || phase == 'temp-fallback') {
      _tempCoalesceQueued = true;
      if (_tempCoalesceRunning) {
        return;
      }
      _tempCoalesceRunning = true;
      final epoch = _tempCoalesceEpoch;
      _tempCoalesceRunnerEpoch = epoch;
      try {
        while (_tempCoalesceQueued &&
            mounted &&
            epoch == _tempCoalesceEpoch) {
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

    // A final route result supersedes any queued temporary geometry.
    // Throttle native final updates so a burst of Directions responses does not
    // repeatedly submit the entire growing LineString to Mapbox.
    if (phase == 'final' || phase == 'final-fallback') {
      _invalidateTempCoalesce();
      _finalCoalesceQueued = true;
      if (_finalCoalesceRunning) {
        return;
      }
      _finalCoalesceRunning = true;
      final epoch = _finalCoalesceEpoch;
      _finalCoalesceRunnerEpoch = epoch;
      try {
        while (_finalCoalesceQueued &&
            mounted &&
            epoch == _finalCoalesceEpoch) {
          _finalCoalesceQueued = false;

          // Give additional Directions results a short window to arrive so
          // only the newest complete geometry is sent to the native Mapbox layer.
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

    final path = _flattenedRoadPath;
    if (path.length < 2) return;

    final simplifiedPath = path.length > 140
        ? RoutePlanGeometry.sampleByDistance(
            path,
            stepMeters: 30,
            maxPoints: 140,
          )
        : path;

    final polyManager = polylineAnnotationManager;
    if (polyManager == null) return;

    final redrawSeq = ++_lineRedrawSeq;
    _lineRedrawQueued = true;

    if (_lineRedrawBusy) return;

    _lineRedrawBusy = true;
    _lineRedrawDone = Completer<void>();
    try {
      while (_lineRedrawQueued && mounted) {
        _lineRedrawQueued = false;

        final line = _drawLine;
        _drawLine = null;

        if (line != null) {
          try {
            await polyManager.delete(line);
          } catch (_) {}
        }

        if (!mounted) break;
        if (redrawSeq != _lineRedrawSeq && _lineRedrawQueued) continue;

        final points = simplifiedPath
            .map((p) => Position(p.longitude, p.latitude))
            .toList(growable: false);

        final created = await polyManager.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: points),
            lineColor: const Color(0xFF1565C0).value,
            lineWidth: 5.0,
            lineOpacity: 0.95,
          ),
        );
        _drawLine = created;
      }
    } finally {
      _lineRedrawBusy = false;
      final done = _lineRedrawDone;
      _lineRedrawDone = null;
      if (done != null && !done.isCompleted) done.complete();
    }
  }

  Future<void> undoLastDrawPoint() async {
    if (!mounted || _undoBusy || _drawPoints.isEmpty) return;
    _undoBusy = true;
    try {
      _drawMutationSeq++;
      _drawSession++;
      _lineRedrawSeq++;
      _invalidateFinalCoalesce();
      _invalidateTempCoalesce();

      _drawPoints.removeLast();
      if (_roadSegments.isNotEmpty) {
        _roadSegments.removeLast();
      }

      await _redrawDrawLine(phase: 'final');
      if (mounted) setState(() {});
    } finally {
      _undoBusy = false;
    }
  }

  Future<void> saveDrawnRoute() async {
    if (!mounted || _drawPoints.length < 2) return;

    final path = _flattenedRoadPath;
    if (path.length < 2) {
      MapUtils.showSnackBar(context, 'أضف نقطتين على الأقل', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      MapUtils.showSnackBar(context, 'يجب تسجيل الدخول أولاً', isError: true);
      return;
    }

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AdminSaveDrawnRouteSheet(
        nameController: nameController,
        descriptionController: descriptionController,
        onSave: () async {
          final name = nameController.text.trim();
          if (name.isEmpty) {
            MapUtils.showSnackBar(context, 'أدخل اسم المسار', isError: true);
            return false;
          }

          try {
            final route = PlannedRoute(
              id: '',
              name: name,
              description: descriptionController.text.trim(),
              geometry: path,
              createdAt: DateTime.now(),
              createdBy: user.uid,
            );

            await _drawRouteService.savePlannedRoute(route);
            if (mounted) Navigator.of(context).pop(true);
            return true;
          } catch (e) {
            MapUtils.log('save drawn route: $e', tag: 'AdminDrawRoute');
            if (mounted) {
              MapUtils.showSnackBar(
                context,
                'تعذر حفظ المسار: $e',
                isError: true,
              );
            }
            return false;
          }
        },
      ),
    );

    nameController.dispose();
    descriptionController.dispose();

    if (result == true && mounted) {
      await cancelDrawingRoute();
      MapUtils.showSnackBar(context, 'تم حفظ المسار بنجاح');
    }
  }

  void disposeAdminDrawRoute() {
    _drawSession++;
    _drawMutationSeq++;
    _lineRedrawSeq++;
    _invalidateFinalCoalesce();
    _invalidateTempCoalesce();
    _tapLocked = false;
    _lineRedrawQueued = false;
    _lineRedrawBusy = false;
    _lineRedrawDone = null;
    _segmentOpBusy = false;
    _segmentOpDone = null;
    _directionsBusy = false;
    _directionsDone = null;
    _drawLine = null;
    _drawPoints.clear();
    _roadSegments.clear();
    isDrawingRoute = false;
    isSnappingSegment = false;
  }

  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180;
}
