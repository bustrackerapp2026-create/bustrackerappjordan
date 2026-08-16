import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_route_painter.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/planned_route.dart';
import '../../../../services/route_plan_service.dart';

/// عرض وإخفاء مسارات plannedRoutes المعتمدة على خريطة الأدمن.
mixin AdminPlannedRoutesMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _plannedService = RoutePlanService();
  StreamSubscription<List<PlannedRoute>>? _plannedSub;

  final List<PolylineAnnotation> _plannedAnns = [];
  List<PlannedRoute> _plannedRoutes = const [];
  bool _drawingPlanned = false;

  /// إظهار المسارات على الخريطة (افتراضي: ظاهر)
  bool showPlannedRoutes = true;

  final ValueNotifier<int> plannedRoutesUiTick = ValueNotifier<int>(0);

  int get plannedRoutesCount => _plannedRoutes.length;

  static const int _outboundColor = 0xFF1D8FE1;
  static const int _returnColor = 0xFF0E9F5D;

  void listenToPlannedRoutes() {
    _plannedSub?.cancel();
    _plannedSub = _plannedService.watchAllApprovedRoutes().listen(
      (routes) {
        _plannedRoutes = routes;
        plannedRoutesUiTick.value++;
        unawaited(_drawPlannedRoutes());
      },
      onError: (e) {
        MapUtils.log('admin planned routes: $e', tag: 'AdminPlanned');
      },
    );
  }

  Future<void> togglePlannedRoutesVisibility() async {
    showPlannedRoutes = !showPlannedRoutes;
    plannedRoutesUiTick.value++;
    if (showPlannedRoutes) {
      await _drawPlannedRoutes();
    } else {
      await _clearPlannedLines();
    }
  }

  Future<void> _drawPlannedRoutes() async {
    if (!mounted || _drawingPlanned) return;
    if (!showPlannedRoutes) {
      await _clearPlannedLines();
      return;
    }

    _drawingPlanned = true;
    try {
      if (polylineAnnotationManager == null && mapboxMap != null) {
        await initPolylineManager();
      }
      if (polylineAnnotationManager == null || !mounted) return;

      await _clearPlannedLines();

      for (final route in _plannedRoutes) {
        if (route.points.length < 2) continue;
        final coords = route.points
            .map((p) => Position(p.longitude, p.latitude))
            .toList();
        final color = route.direction == RouteDirection.outbound
            ? _outboundColor
            : _returnColor;

        final strokes = MapRoutePainter.buildDualStroke(
          coordinates: coords,
          lineColor: color,
        );

        for (final options in strokes) {
          try {
            final ann = await polylineAnnotationManager!.create(options);
            _plannedAnns.add(ann);
          } catch (e) {
            MapUtils.log('draw planned: $e', tag: 'AdminPlanned');
          }
        }
      }
    } finally {
      _drawingPlanned = false;
    }
  }

  Future<void> _clearPlannedLines() async {
    for (final ann in _plannedAnns) {
      try {
        await polylineAnnotationManager?.delete(ann);
      } catch (_) {}
    }
    _plannedAnns.clear();
  }

  Future<void> redrawPlannedRoutes() => _drawPlannedRoutes();

  void disposePlannedRoutes() {
    _plannedSub?.cancel();
    _plannedSub = null;
    _plannedAnns.clear();
    _plannedRoutes = const [];
    plannedRoutesUiTick.dispose();
  }
}
