import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_route_painter.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/planned_route.dart';
import '../../../../services/route_plan_service.dart';
import '../../../widgets/admin_route_direction_filter.dart';

/// عرض وإخفاء مسارات plannedRoutes المعتمدة على خريطة الأدمن
/// مع فلتر ذهاب / إياب / الكل.
mixin AdminPlannedRoutesMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _plannedService = RoutePlanService();
  StreamSubscription<List<PlannedRoute>>? _plannedSub;

  final List<PolylineAnnotation> _plannedAnns = [];
  List<PlannedRoute> _plannedRoutes = const [];
  bool _drawingPlanned = false;

  /// إظهار المسارات على الخريطة (افتراضي: ظاهر)
  bool showPlannedRoutes = true;

  /// فلتر الاتجاه: الكل / ذهاب / إياب
  AdminRouteDirectionFilter plannedRouteFilter =
      AdminRouteDirectionFilter.all;

  final ValueNotifier<int> plannedRoutesUiTick = ValueNotifier<int>(0);

  int get plannedRoutesCount => _plannedRoutes.length;

  int get outboundRoutesCount => _plannedRoutes
      .where((r) => r.direction == RouteDirection.outbound)
      .length;

  int get returnRoutesCount => _plannedRoutes
      .where((r) => r.direction == RouteDirection.returnTrip)
      .length;

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

  /// تغيير فلتر الاتجاه ثم إعادة الرسم
  Future<void> setPlannedRouteFilter(AdminRouteDirectionFilter filter) async {
    if (plannedRouteFilter == filter) return;
    plannedRouteFilter = filter;
    // عند اختيار فلتر نضمن أن العرض مفعّل
    if (!showPlannedRoutes) {
      showPlannedRoutes = true;
    }
    plannedRoutesUiTick.value++;
    await _drawPlannedRoutes();
  }

  List<PlannedRoute> get _filteredRoutes {
    switch (plannedRouteFilter) {
      case AdminRouteDirectionFilter.all:
        return _plannedRoutes;
      case AdminRouteDirectionFilter.outbound:
        return _plannedRoutes
            .where((r) => r.direction == RouteDirection.outbound)
            .toList();
      case AdminRouteDirectionFilter.returnTrip:
        return _plannedRoutes
            .where((r) => r.direction == RouteDirection.returnTrip)
            .toList();
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

      final toDraw = _filteredRoutes;
      for (final route in toDraw) {
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
