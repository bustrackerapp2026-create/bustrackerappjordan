import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/route_service.dart';
import '../../../../models/route_model.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_constants.dart';
import '../../../../core/map/map_route_painter.dart';

mixin RouteManagerMixin<T extends StatefulWidget> on State<T>, MapCoreMixin<T> {
  final List<RouteModel> routes = [];
  final Map<String, List<GeoPoint>> routeCoordinates = {};
  StreamSubscription<List<RouteModel>>? _routesSubscription;

  final ValueNotifier<int> routesUiTick = ValueNotifier<int>(0);

  String selectedRouteName = 'الكل';

  Timer? _drawDebounce;
  bool _isDrawing = false;
  int _drawGeneration = 0;

  List<String> get routeDropdownItems {
    final names = routes.map((r) => r.name).toList();
    return ['الكل', ...names];
  }

  void listenToRoutes() {
    _routesSubscription?.cancel();

    final routeService = RouteService();
    _routesSubscription = routeService.getActiveRoutesStream().listen(
      (list) {
        if (!mounted) return;

        final oldIds = routes.map((r) => r.id).join(',');
        final newIds = list.map((r) => r.id).join(',');

        routes
          ..clear()
          ..addAll(list);

        if (selectedRouteName != 'الكل' &&
            !routes.any((r) => r.name == selectedRouteName)) {
          selectedRouteName = 'الكل';
        }

        if (oldIds != newIds) {
          routesUiTick.value++;
        }

        _log('📦 تم استلام ${list.length} مسار نشط');
        _loadRouteCoordinates();
      },
      onError: (error) {
        _log('❌ خطأ في جلب المسارات: $error');
      },
    );
  }

  Future<void> _loadRouteCoordinates() async {
    final routeService = RouteService();
    final snapshot = List<RouteModel>.from(routes);
    if (snapshot.isEmpty) {
      // لا نستدعي drawRoutes هنا حتى لا يُمسح رسم plannedRoutes عبر deleteAll
      return;
    }

    await Future.wait(snapshot.map((route) async {
      if (!mounted) return;
      if (routeCoordinates.containsKey(route.id) &&
          (routeCoordinates[route.id]?.length ?? 0) >= 2) {
        return;
      }
      try {
        final coords = await routeService.fetchRouteCoordinates(route.id);
        if (coords.isNotEmpty) {
          routeCoordinates[route.id] = coords;
          _log('✅ تم تحميل ${coords.length} نقطة للمسار ${route.name}');
        }
      } catch (e) {
        _log('⚠️ خطأ في تحميل إحداثيات ${route.id}: $e');
      }
    }));

    if (mounted) _scheduleDraw();
  }

  void _scheduleDraw() {
    _drawDebounce?.cancel();
    _drawDebounce = Timer(const Duration(milliseconds: 80), () {
      if (mounted) drawRoutes();
    });
  }

  Future<void> drawRoutes() async {
    if (!mounted || _isDrawing) {
      if (_isDrawing) _scheduleDraw();
      return;
    }
    // لا تمسح كل الـ polylines إن لم توجد مسارات routes (حتى تبقى plannedRoutes)
    if (routes.isEmpty) return;

    _isDrawing = true;
    final gen = ++_drawGeneration;

    try {
      if (polylineAnnotationManager == null) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (polylineAnnotationManager == null || !mounted) return;
      }

      await polylineAnnotationManager?.deleteAll();
      if (!mounted || gen != _drawGeneration) return;

      final toDraw = selectedRouteName == 'الكل'
          ? routes
          : routes.where((r) => r.name == selectedRouteName).toList();

      for (final route in toDraw) {
        if (!mounted || gen != _drawGeneration) return;
        final coords = routeCoordinates[route.id];
        if (coords == null || coords.length < 2) continue;

        final positions =
            coords.map((geo) => Position(geo.longitude, geo.latitude)).toList();

        final lineColor = MapRoutePainter.parseHexColor(route.routeColor);
        final strokes = MapRoutePainter.buildDualStroke(
          coordinates: positions,
          lineColor: lineColor,
        );

        for (final options in strokes) {
          try {
            await polylineAnnotationManager?.create(options);
          } catch (e) {
            _log('⚠️ خطأ في رسم ${route.id}: $e');
          }
        }
      }
    } finally {
      _isDrawing = false;
    }
  }

  void onRouteFilterChanged(String name) {
    selectedRouteName = name;
    routesUiTick.value++;
    drawRoutes();

    if (name != 'الكل') {
      RouteModel? route;
      for (final r in routes) {
        if (r.name == name) {
          route = r;
          break;
        }
      }
      if (route != null) {
        final coords = routeCoordinates[route.id];
        if (coords != null && coords.isNotEmpty) {
          final mid = coords[coords.length ~/ 2];
          flyToFlat(
            latitude: mid.latitude,
            longitude: mid.longitude,
            zoom: MapConstants.routeFocusZoom,
          );
        }
      }
    }
  }

  void redrawRoutes() {
    if (mounted) _scheduleDraw();
  }

  void disposeRoutes() {
    _drawDebounce?.cancel();
    _routesSubscription?.cancel();
    routesUiTick.dispose();
    routes.clear();
    routeCoordinates.clear();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('📌 [AdminMap] $message');
  }
}
