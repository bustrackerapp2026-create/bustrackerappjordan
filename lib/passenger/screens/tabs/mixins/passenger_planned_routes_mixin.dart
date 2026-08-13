import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
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
  bool _drawingPlannedRoutes = false;
  List<PlannedRoute> _lastPlannedRoutes = const [];

  /// ألوان ثابتة: ذهاب أزرق، إياب أخضر
  static const int _outboundColor = 0xFF2563EB;
  static const int _returnColor = 0xFF059669;

  void startWatchingPlannedRoutes(String lineName) {
    if (lineName.trim().isEmpty) return;
    if (_plannedRoutesLineFilter == lineName) return;
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
    if (_plannedRoutesLineFilter == lineName) return;
    startWatchingPlannedRoutes(lineName);
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
        try {
          final ann = await polylineAnnotationManager!.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: coords),
              lineColor: isOutbound ? _outboundColor : _returnColor,
              lineWidth: 4.5,
              lineOpacity: 0.85,
            ),
          );
          _plannedLineAnnotations.add(ann);
        } catch (e) {
          MapUtils.log('draw planned route: $e', tag: 'PassengerRoutes');
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
