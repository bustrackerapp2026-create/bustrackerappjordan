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

  /// 'الكل' أو اسم المسار المعروض في القائمة
  String selectedRouteName = 'الكل';

  /// أسماء المسارات للقائمة المنسدلة (تبدأ بـ الكل)
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
        _log('📦 تم استلام ${list.length} مسار نشط');
        routes
          ..clear()
          ..addAll(list);

        // إن كان المسار المختار لم يعد موجوداً، ارجع للكل
        if (selectedRouteName != 'الكل' &&
            !routes.any((r) => r.name == selectedRouteName)) {
          selectedRouteName = 'الكل';
        }

        setState(() {});
        _loadRouteCoordinates();
      },
      onError: (error) {
        _log('❌ خطأ في جلب المسارات: $error');
      },
    );
  }

  Future<void> _loadRouteCoordinates() async {
    final routeService = RouteService();

    for (final route in routes) {
      if (!mounted) return;
      try {
        final coords = await routeService.fetchRouteCoordinates(route.id);
        if (coords.isNotEmpty) {
          routeCoordinates[route.id] = coords;
          _log('✅ تم تحميل ${coords.length} نقطة للمسار ${route.name}');
        } else {
          _log('⚠️ لا إحداثيات للمسار ${route.name} (${route.id})');
        }
      } catch (e) {
        _log('⚠️ خطأ في تحميل إحداثيات المسار ${route.id}: $e');
      }
    }

    if (mounted) {
      await drawRoutes();
    }
  }

  Future<void> drawRoutes() async {
    if (!mounted) return;

    // انتظر جاهزية مدير الخطوط قليلاً إن لزم
    if (polylineAnnotationManager == null) {
      _log('⏳ مدير الخطوط غير جاهز بعد — إعادة المحاولة...');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (polylineAnnotationManager == null || !mounted) {
        _log('❌ تعذر رسم المسارات: لا يوجد PolylineAnnotationManager');
        return;
      }
    }

    if (routes.isEmpty) {
      await polylineAnnotationManager?.deleteAll();
      _log('ℹ️ لا مسارات نشطة للرسم');
      return;
    }

    await polylineAnnotationManager?.deleteAll();

    final toDraw = selectedRouteName == 'الكل'
        ? routes
        : routes.where((r) => r.name == selectedRouteName).toList();

    for (final route in toDraw) {
      if (!mounted) return;
      final coords = routeCoordinates[route.id];
      if (coords == null || coords.isEmpty) continue;

      final positions =
          coords.map((geo) => Position(geo.longitude, geo.latitude)).toList();
      if (positions.length < 2) continue;

      final color = hexToColor(route.routeColor);

      final options = PolylineAnnotationOptions(
        geometry: LineString(coordinates: positions),
        lineColor: color.toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.9,
      );

      try {
        await polylineAnnotationManager?.create(options);
        _log('✅ تم رسم المسار: ${route.name}');
      } catch (e) {
        _log('⚠️ خطأ في رسم المسار ${route.id}: $e');
      }
    }
  }

  void onRouteFilterChanged(String name) {
    selectedRouteName = name;
    setState(() {});
    drawRoutes();

    // ركّز الكاميرا على المسار المختار
    if (name != 'الكل') {
      final route = routes.where((r) => r.name == name).firstOrNull;
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
    if (mounted) {
      drawRoutes();
    }
  }

  void disposeRoutes() {
    _routesSubscription?.cancel();
    routes.clear();
    routeCoordinates.clear();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('📌 [AdminMap] $message');
    }
  }
}
