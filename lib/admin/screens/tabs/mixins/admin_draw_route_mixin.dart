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
    if (!isDrawingRoute || !mounted || isSnappingSegment) return;

    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();

    final raw = RoutePoint(
      latitude: lat,
      longitude: lng,
    );

    setState(() {
      isSnappingSegment = true;
    });

    try {
      // لا نعتمد على Map Matching لنقطة منفردة.
      // snapPointToRoad في RoutePlanMapbox أصبحت تعيد النقطة
      // الأصلية عندما لا توجد نافذة متعددة النقاط.
      final snapped = await _drawRouteService.snapPointToRoad(raw);

      if (!mounted) return;

      // منع النقاط المتقاربة جداً.
      if (_drawPoints.isNotEmpty) {
        final last = _drawPoints.last;

        final distance = _haversineMeters(
          last.latitude,
          last.longitude,
          snapped.latitude,
          snapped.longitude,
        );

        if (distance < 15) {
          MapUtils.showSnackBar(
            context,
            'النقطة قريبة جداً من السابقة',
          );
          return;
        }
      }

      // حفظ النقطة الجديدة أولاً.
      _drawPoints.add(snapped);

      // إنشاء Marker للنقطة.
      if (pointAnnotationManager != null) {
        try {
          final marker = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(
                  snapped.longitude,
                  snapped.latitude,
                ),
              ),
              iconSize: 0.6,
            ),
          );

          _drawPointMarkers.add(marker);
        } catch (e) {
          MapUtils.log(
            'draw point marker: $e',
            tag: 'AdminDraw',
          );
        }
      }

      // لا يوجد مقطع مع النقطة الأولى.
      if (_drawPoints.length < 2) {
        await _redrawDrawLine();
        if (mounted) {
          setState(() {});
        }
        return;
      }

      final from = _drawPoints[_drawPoints.length - 2];
      final to = _drawPoints.last;

      // ============================================================
      // المرحلة 1: رسم فوري
      // ============================================================
      //
      // لا ننتظر Mapbox.
      //
      // نضع المقطع المباشر مؤقتاً حتى يظهر للمستخدم فوراً.
      // سيتم استبداله بمسار الطرق بعد عودة Directions.
      final segmentIndex = _roadSegments.length;

      _roadSegments.add([
        from,
        to,
      ]);

      await _redrawDrawLine();

      if (mounted) {
        setState(() {});
      }

      // ============================================================
      // المرحلة 2: تحسين المقطع بواسطة Directions
      // ============================================================
      final road = await _drawRouteService.getDrivingPath(
        from: from,
        to: to,
      );

      if (!mounted) return;

      // تأكد أن المقطع الذي سنستبدله ما زال هو آخر مقطع.
      //
      // حالياً isSnappingSegment يمنع إضافة نقطة جديدة أثناء
      // معالجة الطلب، لذلك هذا هو الوضع المتوقع دائماً.
      if (segmentIndex < _roadSegments.length) {
        if (road.length >= 2) {
          _roadSegments[segmentIndex] = road;
        } else {
          // فشل Directions:
          // نحتفظ بالمقطع المباشر بدلاً من إخفائه.
          _roadSegments[segmentIndex] = [
            from,
            to,
          ];
        }
      }

      // تحديث الخط بعد وصول نتيجة الطريق.
      await _redrawDrawLine();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      MapUtils.log(
        'draw tap: $e',
        tag: 'AdminDraw',
      );

      // إذا حدث خطأ بعد إضافة النقطة، لا نحذف النقطة.
      // وإذا كان هناك مقطع أخير، نضمن بقاء خط مباشر بين الطرفين.
      if (mounted && _drawPoints.length >= 2) {
        final from = _drawPoints[_drawPoints.length - 2];
        final to = _drawPoints.last;

        if (_roadSegments.length < _drawPoints.length - 1) {
          _roadSegments.add([
            from,
            to,
          ]);
        }

        await _redrawDrawLine();

        MapUtils.showSnackBar(
          context,
          'تمت إضافة النقطة، لكن تعذر تحسين المقطع بالطريق',
          isError: true,
        );

        setState(() {});
      } else if (mounted) {
        MapUtils.showSnackBar(
          context,
          'تعذر إضافة النقطة',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSnappingSegment = false;
        });
      }
    }
  }

  /// إعادة رسم خط المسار الحالي.
  Future<void> _redrawDrawLine() async {
    if (!mounted) return;

    final path = _flattenedRoadPath;

    if (path.length < 2 || polylineAnnotationManager == null) {
      if (_drawLine != null) {
        try {
          await polylineAnnotationManager?.delete(_drawLine!);
        } catch (_) {}

        _drawLine = null;
      }

      return;
    }

    final coords = <Position>[
      for (final point in path)
        Position(
          point.longitude,
          point.latitude,
        ),
    ];

    final geometry = LineString(
      coordinates: coords,
    );

    try {
      if (_drawLine != null) {
        _drawLine!.geometry = geometry;

        await polylineAnnotationManager!.update(
          _drawLine!,
        );
      } else {
        _drawLine = await polylineAnnotationManager!.create(
          PolylineAnnotationOptions(
            geometry: geometry,
            lineColor: 0xFF7C3AED,
            lineWidth: 5.0,
          ),
        );
      }
    } catch (e) {
      MapUtils.log(
        'draw line: $e',
        tag: 'AdminDraw',
      );
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
    _drawPoints.clear();
    _roadSegments.clear();
    _drawLine = null;
    _drawPointMarkers.clear();

    isDrawingRoute = false;
    isSnappingSegment = false;
  }
}
