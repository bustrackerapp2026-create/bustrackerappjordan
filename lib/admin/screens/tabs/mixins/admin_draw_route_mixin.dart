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

  Future<void> _clearDrawVisuals() async {
    final clearGen = ++_visualClearGen;
    _lineRedrawQueued = false;

    final pending = _lineRedrawDone;
    if (pending != null) {
      await pending.future;
    }

    // clear أحدث تولّى المسؤولية
    if (clearGen != _visualClearGen) return;

    // لقطة متزامنة — لا نحذف ما يُنشأ بعدها
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
          if (session != _drawSession) return;
          _drawPointMarkers.add(marker);
        }
      } catch (e) {
        MapUtils.log('draw point marker: $e', tag: 'AdminDraw');
      }

      if (_drawPoints.length < 2) {
        await _redrawDrawLine();
        if (mounted) setState(() {});
        return;
      }

      from = _drawPoints[_drawPoints.length - 2];
      to = _drawPoints.last;

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
      // الرسم الحي: هندسة الطريق فقط — بدون stitch إلى نقاط النقر
      final road = await _drawRouteService.getDrivingPath(
        from: a,
        to: b,
        attachControlEndpoints: false,
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
      await _redrawDrawLine();
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
        await _redrawDrawLine();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _redrawDrawLine() async {
    if (!mounted) return;

    // طلبات إضافية أثناء الدورة الحالية → coalescing فقط
    if (_lineRedrawBusy) {
      _lineRedrawQueued = true;
      return;
    }

    _lineRedrawBusy = true;
    final done = Completer<void>();
    _lineRedrawDone = done;
    final visualGen = _visualClearGen;

    try {
      do {
        _lineRedrawQueued = false;
        if (!mounted) break;

        final session = _drawSession;
        final path = List<RoutePoint>.from(_flattenedRoadPath);
        final manager = polylineAnnotationManager;

        // session guard: لا تكمل إن تغيّرت الجلسة
        if (session != _drawSession) break;

        if (path.length < 2 || manager == null) {
          final old = _drawLine;
          _drawLine = null;
          if (old != null) {
            try {
              await manager?.delete(old);
            } catch (_) {}
          }
          continue;
        }

        final coords = <Position>[
          for (final p in path) Position(p.longitude, p.latitude),
        ];
        final geometry = LineString(coordinates: coords);

        // تحديث الخط الحالي إن وُجد (نفس manager الذي أنشأه)
        if (_drawLine != null) {
          try {
            _drawLine!.geometry = geometry;
            await manager.update(_drawLine!);
            continue;
          } catch (e) {
            MapUtils.log('draw line update fallback: $e', tag: 'AdminDraw');
          }
        }

        // fallback: أنشئ الخط الجديد أولاً ثم احذف السابق
        PolylineAnnotation? created;
        try {
          created = await manager.create(
            PolylineAnnotationOptions(
              geometry: geometry,
              lineColor: 0xFF7C3AED,
              lineWidth: 5.0,
            ),
          );
        } catch (e) {
          MapUtils.log('draw line: $e', tag: 'AdminDraw');
          continue;
        }

        // session guard بعد create
        if (!mounted || session != _drawSession) {
          try {
            await manager.delete(created);
          } catch (_) {}
          break;
        }

        final previous = _drawLine;
        _drawLine = created;
        if (previous != null) {
          try {
            await manager.delete(previous);
          } catch (_) {}
        }
      } while (_lineRedrawQueued && mounted);
    } finally {
      _lineRedrawBusy = false;
      _lineRedrawDone = null;
      if (!done.isCompleted) {
        done.complete();
      }
      // لا تُعِد التشغيل إن بدأ clear أحدث أثناء هذه الدورة
      if (_lineRedrawQueued &&
          mounted &&
          visualGen == _visualClearGen) {
        _lineRedrawQueued = false;
        unawaited(_redrawDrawLine());
      }
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

      await _redrawDrawLine();

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
    _drawPointMarkers.clear();
    _drawCircleManager = null;

    isDrawingRoute = false;
    isSnappingSegment = false;
  }
}
