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

/// رسم مسار أدمن مع لصق حي على الشبكة الطرقية (نقطة → شارع → Directions).
mixin AdminDrawRouteMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _drawRouteService = RoutePlanService();

  bool isDrawingRoute = false;
  bool isSnappingSegment = false;
  final List<RoutePoint> _drawPoints = [];
  final List<List<RoutePoint>> _roadSegments = [];

  PolylineAnnotation? _drawLine;
  final List<PointAnnotation> _drawPointMarkers = [];

  List<RoutePoint> get _flattenedRoadPath {
    if (_roadSegments.isEmpty) return List.of(_drawPoints);
    final out = <RoutePoint>[];
    for (final seg in _roadSegments) {
      if (out.isEmpty) {
        out.addAll(seg);
      } else if (seg.isNotEmpty) {
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
    for (final m in _drawPointMarkers) {
      try {
        await pointAnnotationManager?.delete(m);
      } catch (_) {}
    }
    _drawPointMarkers.clear();
  }

  Future<void> onDrawRouteMapTap(Point point) async {
    if (!isDrawingRoute || !mounted || isSnappingSegment) return;
    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();
    setState(() => isSnappingSegment = true);
    try {
      final raw = RoutePoint(latitude: lat, longitude: lng);
      final snapped = await _drawRouteService.snapPointToRoad(raw);

      if (_drawPoints.isNotEmpty) {
        final last = _drawPoints.last;
        final d = _haversineMeters(
          last.latitude,
          last.longitude,
          snapped.latitude,
          snapped.longitude,
        );
        if (d < 15) {
          if (mounted) {
            MapUtils.showSnackBar(context, 'النقطة قريبة جداً من السابقة');
          }
          return;
        }
      }

      _drawPoints.add(snapped);

      if (pointAnnotationManager != null) {
        final ann = await pointAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(snapped.longitude, snapped.latitude),
            ),
            iconSize: 0.6,
          ),
        );
        _drawPointMarkers.add(ann);
      }

      if (_drawPoints.length >= 2) {
        final from = _drawPoints[_drawPoints.length - 2];
        final to = _drawPoints.last;
        final road = await _drawRouteService.getDrivingPath(
          from: from,
          to: to,
        );
        _roadSegments.add(road.length >= 2 ? road : [from, to]);
      }

      await _redrawDrawLine();
      if (mounted) setState(() {});
    } catch (e) {
      MapUtils.log('draw tap: $e', tag: 'AdminDraw');
      if (mounted) {
        MapUtils.showSnackBar(context, 'تعذر إضافة النقطة', isError: true);
      }
    } finally {
      if (mounted) setState(() => isSnappingSegment = false);
    }
  }

  Future<void> _redrawDrawLine() async {
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
    final coords = [
      for (final p in path) Position(p.longitude, p.latitude),
    ];
    try {
      if (_drawLine != null) {
        _drawLine!.geometry = LineString(coordinates: coords);
        await polylineAnnotationManager!.update(_drawLine!);
      } else {
        _drawLine = await polylineAnnotationManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: 0xFF7C3AED,
            lineWidth: 5.0,
          ),
        );
      }
    } catch (e) {
      MapUtils.log('draw line: $e', tag: 'AdminDraw');
    }
  }

  Future<void> undoLastDrawPoint() async {
    if (_drawPoints.isEmpty || isSnappingSegment) return;
    _drawPoints.removeLast();
    if (_roadSegments.isNotEmpty) _roadSegments.removeLast();

    if (_drawPointMarkers.isNotEmpty) {
      final last = _drawPointMarkers.removeLast();
      try {
        await pointAnnotationManager?.delete(last);
      } catch (_) {}
    }
    await _redrawDrawLine();
    if (mounted) setState(() {});
  }

  double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double d) => d * math.pi / 180;

  String _friendlySaveError(Object e) {
    final s = e.toString();
    if (s.contains('permission') || s.contains('PERMISSION')) {
      return 'رفض الصلاحيات على plannedRoutes — انشر firestore.rules ثم أعد المحاولة.';
    }
    return s;
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

      final control = List<RoutePoint>.from(_drawPoints);

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
      MapUtils.log('save drawn route: $e', tag: 'AdminDraw');
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
