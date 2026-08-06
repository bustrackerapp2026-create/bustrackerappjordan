import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/route_service.dart';
import '../../../../models/route_model.dart';
import '../../../../core/map/map_core.dart';

mixin RouteManagerMixin<T extends StatefulWidget> on State<T>, MapCoreMixin<T> {
  final List<RouteModel> _routes = [];
  final Map<String, List<GeoPoint>> _routeCoordinates = {};
  StreamSubscription<List<RouteModel>>? _routesSubscription;

  void listenToRoutes() {
    _routesSubscription?.cancel();

    final routeService = RouteService();
    _routesSubscription = routeService.getActiveRoutesStream().listen(
      (routes) {
        if (!mounted) return;
        _log('📦 تم استلام ${routes.length} مسار نشط');
        _routes.clear();
        _routes.addAll(routes);
        _loadRouteCoordinates();
      },
      onError: (error) {
        _log('❌ خطأ في جلب المسارات: $error');
      },
    );
  }

  Future<void> _loadRouteCoordinates() async {
    final routeService = RouteService();

    for (final route in _routes) {
      if (!mounted) return;
      try {
        final coords = await routeService.fetchRouteCoordinates(route.id);
        if (coords.isNotEmpty) {
          _routeCoordinates[route.id] = coords;
          _log('✅ تم تحميل ${coords.length} نقطة للمسار ${route.name}');
        }
      } catch (e) {
        _log('⚠️ خطأ في تحميل إحداثيات المسار ${route.id}: $e');
      }
    }

    if (mounted) {
      _drawRoutes();
    }
  }

  Future<void> _drawRoutes() async {
    if (polylineAnnotationManager == null || _routes.isEmpty || !mounted) {
      return;
    }

    await polylineAnnotationManager?.deleteAll();

    for (final route in _routes) {
      if (!mounted) return;
      final coords = _routeCoordinates[route.id];
      if (coords == null || coords.isEmpty) {
        continue;
      }

      final positions =
          coords.map((geo) => Position(geo.longitude, geo.latitude)).toList();

      if (positions.isEmpty) continue;

      final color = hexToColor(route.routeColor);

      final options = PolylineAnnotationOptions(
        geometry: LineString(coordinates: positions),
        lineColor: color.toARGB32(),
        lineWidth: 4.0,
        lineOpacity: 0.8,
      );

      try {
        await polylineAnnotationManager?.create(options);
        _log('✅ تم رسم المسار: ${route.name}');
      } catch (e) {
        _log('⚠️ خطأ في رسم المسار ${route.id}: $e');
      }
    }
  }

  void redrawRoutes() {
    if (_routes.isNotEmpty && mounted) {
      _drawRoutes();
    }
  }

  void disposeRoutes() {
    _routesSubscription?.cancel();
    _routes.clear();
    _routeCoordinates.clear();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('📌 [AdminMap] $message');
    }
  }
}
