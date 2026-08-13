import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../driver/providers/driver_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../models/planned_route.dart';
import '../../../../models/route_point.dart';
import '../../../../services/route_plan_service.dart';

/// تسجيل مسار خطة الخط (ذهاب / إياب) للسائق.
mixin RoutePlanRecordingMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _routePlanService = RoutePlanService();

  bool isRecordingRoutePlan = false;
  bool isSavingRoutePlan = false;
  RouteDirection? recordingDirection;
  final List<RoutePoint> _routePlanBuffer = [];

  PolylineAnnotationManager? _routePlanLineManager;
  PolylineAnnotation? _routePlanLine;

  List<PlannedRoute> driverPlannedRoutes = const [];
  StreamSubscription<List<PlannedRoute>>? _plannedRoutesSub;

  int get routePlanPointCount => _routePlanBuffer.length;

  Future<void> initRoutePlanLayer() async {
    if (mapboxMap == null) return;
    _routePlanLineManager ??=
        await mapboxMap!.annotations.createPolylineAnnotationManager();
  }

  void listenDriverPlannedRoutes(String driverId) {
    _plannedRoutesSub?.cancel();
    _plannedRoutesSub =
        _routePlanService.watchDriverRoutes(driverId).listen((list) {
      driverPlannedRoutes = list;
      if (mounted) setState(() {});
    });
  }

  PlannedRoute? plannedFor(RouteDirection d, String lineName) {
    for (final r in driverPlannedRoutes) {
      if (r.direction == d && r.lineName == lineName) return r;
    }
    return null;
  }

  /// يبدأ تسجيل مسار الاتجاه المحدد
  Future<void> startRoutePlanRecording({
    required RouteDirection direction,
    required String lineName,
  }) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) {
      MapUtils.showSnackBar(context, '⚠️ سجّل الدخول أولاً', isError: true);
      return;
    }

    final existing = plannedFor(direction, lineName);
    if (existing != null && existing.isLocked) {
      MapUtils.showSnackBar(
        context,
        'المسار ${direction.labelAr} معتمد ومقفول. اطلب تعديلاً من الأدمن.',
        isError: true,
      );
      return;
    }

    final driver = context.read<DriverProvider>();
    if (driver.currentPosition == null) {
      MapUtils.showSnackBar(
        context,
        '⚠️ حدّد موقعك أولاً قبل تسجيل المسار',
        isError: true,
      );
      return;
    }

    await initRoutePlanLayer();

    setState(() {
      isRecordingRoutePlan = true;
      recordingDirection = direction;
      _routePlanBuffer
        ..clear()
        ..add(RoutePoint(
          latitude: driver.currentPosition!.latitude,
          longitude: driver.currentPosition!.longitude,
          timestamp: DateTime.now(),
        ));
    });

    await _redrawRoutePlanLine();
    MapUtils.showSnackBar(
      context,
      '⏺ بدأ تسجيل مسار ${direction.labelAr} — تحرّك على الخط ثم احفظ',
    );
  }

  /// يُستدعى من تحديثات موقع السائق أثناء التسجيل
  void appendRoutePlanPoint(geo.Position pos) {
    if (!isRecordingRoutePlan) return;

    if (_routePlanBuffer.isNotEmpty) {
      final last = _routePlanBuffer.last;
      final dLat = (pos.latitude - last.latitude).abs();
      final dLng = (pos.longitude - last.longitude).abs();
      // ~12 متر تقريباً
      if (dLat < 0.00011 && dLng < 0.00011) return;
    }

    _routePlanBuffer.add(RoutePoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      speed: pos.speed,
      heading: pos.heading,
      accuracy: pos.accuracy,
    ));

    unawaited(_redrawRoutePlanLine());
  }

  Future<void> _redrawRoutePlanLine() async {
    if (_routePlanLineManager == null || _routePlanBuffer.length < 2) return;

    final coords = _routePlanBuffer
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    try {
      if (_routePlanLine != null) {
        _routePlanLine!.geometry = LineString(coordinates: coords);
        await _routePlanLineManager!.update(_routePlanLine!);
      } else {
        _routePlanLine = await _routePlanLineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: const Color(0xFF7C3AED).toARGB32(),
            lineWidth: 5,
            lineOpacity: 0.9,
          ),
        );
      }
    } catch (e) {
      MapUtils.log('route plan line: $e', tag: 'RoutePlan');
    }
  }

  Future<void> cancelRoutePlanRecording() async {
    setState(() {
      isRecordingRoutePlan = false;
      recordingDirection = null;
      _routePlanBuffer.clear();
    });
    await _clearRoutePlanLine();
    if (mounted) {
      MapUtils.showSnackBar(context, 'تم إلغاء تسجيل المسار');
    }
  }

  Future<void> _clearRoutePlanLine() async {
    if (_routePlanLine != null && _routePlanLineManager != null) {
      try {
        await _routePlanLineManager!.delete(_routePlanLine!);
      } catch (_) {}
    }
    _routePlanLine = null;
  }

  Future<void> saveRoutePlanRecording({required String lineName}) async {
    if (!mounted || isSavingRoutePlan) return;
    final direction = recordingDirection;
    if (direction == null) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) return;

    if (_routePlanBuffer.length < RoutePlanService.minPointsToSave) {
      MapUtils.showSnackBar(
        context,
        'المسار قصير جداً. أكمل القيادة على الخط ثم احفظ.',
        isError: true,
      );
      return;
    }

    setState(() => isSavingRoutePlan = true);
    try {
      final saved = await _routePlanService.saveRecordedRoute(
        driverId: uid,
        lineName: lineName,
        direction: direction,
        rawPoints: List<RoutePoint>.from(_routePlanBuffer),
      );

      if (!mounted) return;
      setState(() {
        isRecordingRoutePlan = false;
        recordingDirection = null;
        _routePlanBuffer.clear();
        isSavingRoutePlan = false;
      });
      await _clearRoutePlanLine();

      final km = ((saved.distanceMeters ?? 0) / 1000).toStringAsFixed(1);
      MapUtils.showSnackBar(
        context,
        '✅ تم إرسال مسار ${direction.labelAr} ($km كم) لاعتماد الأدمن',
      );
    } catch (e) {
      if (mounted) {
        setState(() => isSavingRoutePlan = false);
        MapUtils.showSnackBar(context, '❌ $e', isError: true);
      }
    }
  }

  Future<void> requestRoutePlanEdit(PlannedRoute route) async {
    if (!mounted) return;
    try {
      await _routePlanService.requestEdit(routeId: route.id);
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          'تم إرسال طلب تعديل مسار ${route.direction.labelAr} للأدمن',
        );
      }
    } catch (e) {
      if (mounted) {
        MapUtils.showSnackBar(context, '❌ فشل طلب التعديل: $e', isError: true);
      }
    }
  }

  void disposeRoutePlanRecording() {
    _plannedRoutesSub?.cancel();
    _plannedRoutesSub = null;
    _routePlanLine = null;
    _routePlanLineManager = null;
    _routePlanBuffer.clear();
  }
}
