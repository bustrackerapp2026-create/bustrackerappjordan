import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_route_painter.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/planned_route.dart';
import '../../../../services/route_plan_service.dart';

/// رسم مسارات الخط المعتمدة (ذهاب/إياب) على خريطة الركاب.
mixin PassengerPlannedRoutesMixin<T extends StatefulWidget>
    on MapCoreMixin<T> {
  final RoutePlanService _plannedRouteService = RoutePlanService();
  StreamSubscription<List<PlannedRoute>>? _plannedRoutesSub;

  final List<PolylineAnnotation> _plannedLineAnnotations = [];
  String? _plannedRoutesLineFilter;

  /// عند تفعيل «باصات من هنا» / الوجهة نعرض عدة خطوط دفعة واحدة.
  Set<String>? _plannedRoutesMultiFilter;
  bool _drawingPlannedRoutes = false;
  List<PlannedRoute> _lastPlannedRoutes = const [];

  /// ذهاب أزرق، إياب أخضر مواصلات
  static const int _outboundColor = 0xFF1D8FE1;
  static const int _returnColor = 0xFF0E9F5D;

  void startWatchingPlannedRoutes(String lineName) {
    if (lineName.trim().isEmpty) return;
    // الخروج من وضع متعدد الخطوط
    _plannedRoutesMultiFilter = null;
    if (_plannedRoutesLineFilter == lineName && _plannedRoutesSub != null) {
      return;
    }
    _plannedRoutesLineFilter = lineName;

    _plannedRoutesSub?.cancel();
    _plannedRoutesSub = _plannedRouteService
        .watchApprovedRoutesForLine(lineName)
        .listen((routes) {
      _lastPlannedRoutes = routes;
      unawaited(_drawPlannedRoutes(routes));
    }, onError: (e) {
      MapUtils.log('planned routes stream: $e', tag: 'PassengerRoutes');
    });
  }

  void updatePlannedRoutesLineFilter(String lineName) {
    startWatchingPlannedRoutes(lineName);
  }

  /// عرض مسارات عدة خطوط معاً (وضع الموقع / الوجهة).
  void updatePlannedRoutesLineNames(Set<String> lineNames) {
    final cleaned =
        lineNames.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (cleaned.isEmpty) return;

    // خط واحد → نفس المسار السابق
    if (cleaned.length == 1) {
      startWatchingPlannedRoutes(cleaned.first);
      return;
    }

    final same = _plannedRoutesMultiFilter != null &&
        _plannedRoutesMultiFilter!.length == cleaned.length &&
        _plannedRoutesMultiFilter!.containsAll(cleaned);
    if (same && _plannedRoutesSub != null) return;

    _plannedRoutesMultiFilter = cleaned;
    _plannedRoutesLineFilter = null;

    _plannedRoutesSub?.cancel();
    // نراقب كل المعتمد ثم نفلتر بالأسماء محلياً (عدد الخطوط صغير عادة)
    _plannedRoutesSub =
        _plannedRouteService.watchAllApprovedRoutes().listen((all) {
      final filtered = all
          .where((r) => cleaned.contains(r.lineName))
          .toList();
      _lastPlannedRoutes = filtered;
      unawaited(_drawPlannedRoutes(filtered));
    }, onError: (e) {
      MapUtils.log('multi planned routes: $e', tag: 'PassengerRoutes');
    });
  }

  /// رسم فوري من نتائج NearbyRoutesService بدون انتظار الـ stream.
  Future<void> showPlannedRoutesSnapshot(List<PlannedRoute> routes) async {
    _lastPlannedRoutes = List<PlannedRoute>.from(routes);
    await _drawPlannedRoutes(_lastPlannedRoutes);
  }

  Future<void> ensurePlannedRoutesPolylineManager() async {
    if (polylineAnnotationManager == null && mapboxMap != null) {
      await initPolylineManager();
    }
  }

  Future<void> _drawPlannedRoutes(List<PlannedRoute> routes) async {
    if (!mounted || _drawingPlannedRoutes) return;
    _drawingPlannedRoutes = true;
    try {
      await ensurePlannedRoutesPolylineManager();
      if (polylineAnnotationManager == null || !mounted) return;

      for (final ann in _plannedLineAnnotations) {
        try {
          await polylineAnnotationManager!.delete(ann);
        } catch (_) {}
      }
      _plannedLineAnnotations.clear();

      for (final route in routes) {
        if (route.points.length < 2) continue;
        final coords = route.points
            .map((p) => Position(p.longitude, p.latitude))
            .toList();
        final isOutbound = route.direction == RouteDirection.outbound;
        final color = isOutbound ? _outboundColor : _returnColor;

        final strokes = MapRoutePainter.buildDualStroke(
          coordinates: coords,
          lineColor: color,
        );

        for (final options in strokes) {
          try {
            final ann = await polylineAnnotationManager!.create(options);
            _plannedLineAnnotations.add(ann);
          } catch (e) {
            MapUtils.log('draw planned route: $e', tag: 'PassengerRoutes');
          }
        }
      }
    } finally {
      _drawingPlannedRoutes = false;
    }
  }

  Future<void> redrawPlannedRoutes() async {
    if (_lastPlannedRoutes.isEmpty) return;
    await _drawPlannedRoutes(_lastPlannedRoutes);
  }

  void stopWatchingPlannedRoutes() {
    _plannedRoutesSub?.cancel();
    _plannedRoutesSub = null;
    _plannedRoutesLineFilter = null;
    _plannedRoutesMultiFilter = null;
  }

  Future<void> clearPlannedRouteLines() async {
    for (final ann in _plannedLineAnnotations) {
      try {
        await polylineAnnotationManager?.delete(ann);
      } catch (_) {}
    }
    _plannedLineAnnotations.clear();
  }

  void disposePlannedRoutes() {
    stopWatchingPlannedRoutes();
    _plannedLineAnnotations.clear();
    _lastPlannedRoutes = const [];
  }
}
