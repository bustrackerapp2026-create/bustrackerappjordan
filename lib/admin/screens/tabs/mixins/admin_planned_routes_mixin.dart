import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_route_painter.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/route_endpoint_markers.dart';
import '../../../../models/planned_route.dart';
import '../../../../services/route_plan_service.dart';
import '../../../widgets/admin_route_direction_filter.dart';

/// عرض وإخفاء مسارات plannedRoutes المعتمدة على خريطة الأدمن
/// مع فلتر ذهاب / إياب / الكل + علامات البداية والنهاية.
mixin AdminPlannedRoutesMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _plannedService = RoutePlanService();
  StreamSubscription<List<PlannedRoute>>? _plannedSub;

  final List<PolylineAnnotation> _plannedAnns = [];
  final List<PointAnnotation> _endpointAnns = [];
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
  static const int _endColor = 0xFFE11D48;

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
      if (pointAnnotationManager == null && mapboxMap != null) {
        await initAnnotationManager();
      }
      if (polylineAnnotationManager == null || !mounted) return;

      await _clearPlannedLines();

      final toDraw = _filteredRoutes;

      // جهّز صور العلامات مرة واحدة
      final startOut = await RouteEndpointMarkers.start(
        color: const Color(_outboundColor),
      );
      final startRet = await RouteEndpointMarkers.start(
        color: const Color(_returnColor),
      );
      final endOut = await RouteEndpointMarkers.end(
        color: const Color(_endColor),
      );
      final endRet = await RouteEndpointMarkers.end(
        color: const Color(0xFFB45309),
      );

      for (final route in toDraw) {
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
            _plannedAnns.add(ann);
          } catch (e) {
            MapUtils.log('draw planned: $e', tag: 'AdminPlanned');
          }
        }

        // علامات البداية والنهاية
        await _addEndpointMarkers(
          start: route.points.first,
          end: route.points.last,
          startImage: isOutbound ? startOut : startRet,
          endImage: isOutbound ? endOut : endRet,
        );
      }
    } finally {
      _drawingPlanned = false;
    }
  }

  Future<void> _addEndpointMarkers({
    required dynamic start,
    required dynamic end,
    required Uint8List startImage,
    required Uint8List endImage,
  }) async {
    final manager = pointAnnotationManager;
    if (manager == null) return;

    try {
      final startAnn = await manager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(start.longitude, start.latitude),
          ),
          image: startImage,
          iconSize: 0.95,
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: 10,
        ),
      );
      _endpointAnns.add(startAnn);
    } catch (e) {
      MapUtils.log('start marker: $e', tag: 'AdminPlanned');
    }

    try {
      final endAnn = await manager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(end.longitude, end.latitude),
          ),
          image: endImage,
          iconSize: 0.95,
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: 11,
        ),
      );
      _endpointAnns.add(endAnn);
    } catch (e) {
      MapUtils.log('end marker: $e', tag: 'AdminPlanned');
    }
  }

  Future<void> _clearPlannedLines() async {
    for (final ann in _plannedAnns) {
      try {
        await polylineAnnotationManager?.delete(ann);
      } catch (_) {}
    }
    _plannedAnns.clear();

    for (final ann in _endpointAnns) {
      try {
        await pointAnnotationManager?.delete(ann);
      } catch (_) {}
    }
    _endpointAnns.clear();
  }

  Future<void> redrawPlannedRoutes() => _drawPlannedRoutes();

  void disposePlannedRoutes() {
    _plannedSub?.cancel();
    _plannedSub = null;
    _plannedAnns.clear();
    _endpointAnns.clear();
    _plannedRoutes = const [];
    plannedRoutesUiTick.dispose();
  }
}
