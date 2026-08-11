import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/route_service.dart';
import '../../../../models/route_model.dart';
import '../../../../core/map/map_core.dart';

mixin RouteManagerMixin<T extends StatefulWidget> on State<T>, MapCoreMixin<T> {
  final List<RouteModel> routes = [];
  final Map<String, List<GeoPoint>> routeCoordinates = {};
  StreamSubscription<List<RouteModel>>? _routesSubscription;

  /// يُحدَّث عند تغيّر قائمة المسارات فقط — لتحديث الواجهة دون لمس الكاميرا
  final ValueNotifier<int> routesUiTick = ValueNotifier<int>(0);

  String selectedRouteName = 'الكل';

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

        // لا نستدعي setState على شاشة الخريطة كاملة — يمنع رجّة الزوم
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

    for (final route in List<RouteModel>.from(routes)) {
      if (!mounted) return;
      try {
        final coords = await routeService.fetchRouteCoordinates(route.id);
        if (coords.isNotEmpty) {
          routeCoordinates[route.id] = coords;
          _log('✅ تم تحميل ${coords.length} نقطة للمسار ${route.name}');
        }
      } catch (e) {
        _log('⚠️ خطأ في تحميل إحداثيات ${route.id}: $e');
      }
    }

    if (mounted) await drawRoutes();
  }

  Future<void> drawRoutes() async {
    if (!mounted) return;

    if (polylineAnnotationManager == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (polylineAnnotationManager == null || !mounted) return;
    }

    await polylineAnnotationManager?.deleteAll();

    if (routes.isEmpty) return;

    final toDraw = selectedRouteName == 'الكل'
        ? routes
        : routes.where((r) => r.name == selectedRouteName).toList();

    for (final route in toDraw) {
      if (!mounted) return;
      final coords = routeCoordinates[route.id];
      if (coords == null || coords.length < 2) continue;

      final positions =
          coords.map((geo) => Position(geo.longitude, geo.latitude)).toList();

      final color = hexToColor(route.routeColor);
      final options = PolylineAnnotationOptions(
        geometry: LineString(coordinates: positions),
        lineColor: color.toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.9,
      );

      try {
        await polylineAnnotationManager?.create(options);
      } catch (e) {
        _log('⚠️ خطأ في رسم ${route.id}: $e');
      }
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
            zoom: 10.5,
          );
        }
      }
    }
  }

  void redrawRoutes() {
    if (mounted) drawRoutes();
  }

  void disposeRoutes() {
    _routesSubscription?.cancel();
    routesUiTick.dispose();
    routes.clear();
    routeCoordinates.clear();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('📌 [AdminMap] $message');
  }
}
