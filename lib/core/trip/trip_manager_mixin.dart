import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../map/map_core.dart';
import '../map/map_utils.dart';
import '../../driver/providers/driver_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../services/trip_service.dart';
import '../../services/vehicle_trip_service.dart';
import '../../services/driver_line_assignment_service.dart';
import '../../models/trip_status.dart';
import '../../models/route_point.dart';
import '../../models/planned_route.dart';
import '../../models/driver_line_assignment.dart';

mixin TripManagerMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  bool _isProcessingTrip = false;
  String? _currentTripId;
  String? _currentVehicleTripId;
  PlannedRoute? _currentOperationalRoute;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _polylineAnnotation;
  final TripService _tripService = TripService();
  final VehicleTripService _vehicleTripService = VehicleTripService();
  final DriverLineAssignmentService _driverLineAssignmentService = DriverLineAssignmentService();

  static const double _routeStartMatchMaxMeters = 750.0;

  bool get isProcessingTrip => _isProcessingTrip;
  String? get currentTripId => _currentTripId;
  String? get currentVehicleTripId => _currentVehicleTripId;
  PlannedRoute? get currentOperationalRoute => _currentOperationalRoute;

  Future<void> showRouteOnMap(List<RoutePoint> routePoints) async {
    if (routePoints.isEmpty) return;
    if (mapboxMap == null) return;

    if (_polylineAnnotationManager == null) {
      _polylineAnnotationManager =
          await mapboxMap!.annotations.createPolylineAnnotationManager();
    }

    if (_polylineAnnotation != null) {
      await _polylineAnnotationManager?.delete(_polylineAnnotation!);
      _polylineAnnotation = null;
    }

    final positions = routePoints
        .map((p) => Position(p.longitude, p.latitude))
        .toList();
    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: positions),
      lineColor: Colors.blue.toARGB32(),
      lineWidth: 4.0,
      lineOpacity: 0.8,
    );
    _polylineAnnotation =
        await _polylineAnnotationManager?.create(options);
    MapUtils.log(
      '✅ تم رسم المسار - عدد النقاط: ${routePoints.length}',
      tag: 'TripManager',
    );
  }

  Future<PlannedRoute?> _getApprovedRouteForAssignment(
    String routeId,
    String lineId,
  ) async {
    final id = routeId.trim();
    final expectedLineId = lineId.trim();
    if (id.isEmpty || expectedLineId.isEmpty) return null;

    final snap = await FirebaseFirestore.instance
        .collection('plannedRoutes')
        .doc(id)
        .get();
    if (!snap.exists || snap.data() == null) return null;

    final route = PlannedRoute.fromDoc(snap.id, snap.data()!);
    if (!route.isApproved || route.points.length < 2) return null;

    final routeLineId = route.lineId?.trim();
    if (routeLineId == null ||
        routeLineId.isEmpty ||
        routeLineId != expectedLineId) {
      return null;
    }
    return route;
  }

  double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _distanceToRouteStart(
    PlannedRoute route,
    geo.Position current,
  ) {
    final start = route.direction == RouteDirection.outbound
        ? route.points.first
        : route.points.last;
    return _distanceMeters(
      current.latitude,
      current.longitude,
      start.latitude,
      start.longitude,
    );
  }

  Future<AssignedRouteChoice?> _resolveAssignedRoute(
    String driverId,
    geo.Position currentPosition,
  ) async {
    final assignments =
        await _driverLineAssignmentService.getApprovedAssignmentsForDriver(
      driverId,
      limit: 50,
    );

    final candidates = <AssignedRouteChoice>[];
    for (final assignment in assignments) {
      final route = await _getApprovedRouteForAssignment(
        assignment.routeId,
        assignment.lineId,
      );
      if (route == null) continue;

      candidates.add(
        AssignedRouteChoice(
          assignment: assignment,
          route: route,
          distanceMeters: _distanceToRouteStart(route, currentPosition),
        ),
      );
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    final best = candidates.first;
    if (candidates.length > 1 &&
        best.distanceMeters > _routeStartMatchMaxMeters) {
      return null;
    }
    return best;
  }

  /// مصدر الحقيقة للمسار هو التعيين المعتمد للسائق.
  /// عند وجود ذهاب + إياب، يحدد الموقع الحالي أي تعيين يبدأ منه السائق:
  /// ذهاب = أول نقطة، إياب = آخر نقطة في PlannedRoute.
  Future<void> startTrip({String? lineName}) async {
    if (_isProcessingTrip || !mounted) return;

    final driverProvider = context.read<DriverProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId == null || userId.isEmpty) {
      MapUtils.showSnackBar(context, '⚠️ يرجى تسجيل الدخول أولاً.', isError: true);
      return;
    }
    if (!driverProvider.isBound || driverProvider.boundUserId != userId) {
      driverProvider.bindToUser(userId);
    }
    if (!driverProvider.isOnline) {
      MapUtils.showSnackBar(context, '⚠️ يجب أن تكون متاحاً أولاً.', isError: true);
      return;
    }
    if (driverProvider.isTripActive) {
      MapUtils.showSnackBar(context, '⚠️ الرحلة مفعلة بالفعل.', isError: true);
      return;
    }

    final currentPosition = driverProvider.currentPosition;
    if (currentPosition == null) {
      MapUtils.showSnackBar(
        context,
        '⚠️ يرجى تحديد موقعك أولاً (اضغط على زر الموقع).',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessingTrip = true);
    try {
      final resolved = await _resolveAssignedRoute(userId, currentPosition);

      if (resolved == null) {
        final assignments =
            await _driverLineAssignmentService.getApprovedAssignmentsForDriver(
          userId,
          limit: 50,
        );
        final message = assignments.isEmpty
            ? '⚠️ لا يوجد مسار معتمد ومخصص لك. اطلب تعيين مسار من الأدمن أولاً.'
            : assignments.length == 1
                ? '⚠️ المسار المخصص لك غير صالح أو غير مرتبط بالخط التشغيلي المعتمد.'
                : '⚠️ تعذر تحديد اتجاه الرحلة من موقعك الحالي. ابدأ من نقطة بداية الذهاب أو نقطة بداية الإياب.';
        if (mounted) {
          MapUtils.showSnackBar(context, message, isError: true);
        }
        return;
      }

      final assignment = resolved.assignment;
      final route = resolved.route;
      final resolvedLine = route.lineName.trim();

      final requestedLine = (lineName ?? '').trim();
      if (requestedLine.isNotEmpty && requestedLine != resolvedLine) {
        if (mounted) {
          MapUtils.showSnackBar(
            context,
            '⚠️ الخط المختار لا يطابق الخط المعتمد والمخصص لك.',
            isError: true,
          );
        }
        return;
      }

      final busNumber =
          authProvider.userData?.busNumber?.trim().isNotEmpty == true
              ? authProvider.userData!.busNumber!.trim()
              : '—';

      final vehicleTrip = await _vehicleTripService.startTrip(
        driverId: userId,
        busNumber: busNumber,
        routeId: assignment.routeId,
        direction: route.direction.firestoreValue,
        currentLocation: GeoPoint(
          currentPosition.latitude,
          currentPosition.longitude,
        ),
        speed: currentPosition.speed,
        heading: currentPosition.heading,
      );
      if (!mounted) return;

      final started = driverProvider.startTrip(userId: userId);
      if (!started) {
        MapUtils.showSnackBar(
          context,
          '⚠️ تم إنشاء الرحلة التشغيلية لكن تعذر تفعيل الحالة المحلية.',
          isError: true,
        );
        setState(() {
          _currentVehicleTripId = vehicleTrip.id;
          _currentOperationalRoute = route;
        });
        await showRouteOnMap(route.points);
        return;
      }

      setState(() {
        _currentVehicleTripId = vehicleTrip.id;
        _currentOperationalRoute = route;
      });

      await showRouteOnMap(route.points);

      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        '🚀 تم بدء رحلة ${route.direction.labelAr} على المسار المخصص: ${resolvedLine.isEmpty ? '—' : resolvedLine}',
        isError: false,
      );
    } on VehicleTripServiceException catch (e) {
      MapUtils.log('❌ VehicleTrip: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          e.message.isNotEmpty ? e.message : '❌ فشل بدء الرحلة التشغيلية.',
          isError: true,
        );
      }
    } catch (e) {
      MapUtils.log('❌ فشل بدء الرحلة: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          '❌ فشل بدء الرحلة، يرجى المحاولة لاحقاً.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingTrip = false);
    }
  }

  Future<void> endTrip() async {
    if (_isProcessingTrip) return;
    if (!mounted) return;

    final driverProvider = context.read<DriverProvider>();
    final authProvider = context.read<AuthProvider>();
    final driverId = authProvider.userId;
    if (driverId == null || driverId.isEmpty) {
      MapUtils.showSnackBar(context, '⚠️ يرجى تسجيل الدخول أولاً.', isError: true);
      return;
    }
    if (!driverProvider.isBound || driverProvider.boundUserId != driverId) {
      driverProvider.bindToUser(driverId);
    }
    if (!driverProvider.isTripActive) {
      MapUtils.showSnackBar(context, '⚠️ لا توجد رحلة نشطة.', isError: true);
      return;
    }

    final vehicleTripId = _currentVehicleTripId;
    setState(() => _isProcessingTrip = true);
    try {
      if (vehicleTripId != null && vehicleTripId.isNotEmpty) {
        await _vehicleTripService.completeTrip(
          tripId: vehicleTripId,
          driverId: driverId,
        );
      }

      driverProvider.endTrip(userId: driverId);

      if (mounted) {
        setState(() {
          _currentTripId = null;
          _currentVehicleTripId = null;
          _currentOperationalRoute = null;
        });
        if (_polylineAnnotation != null) {
          try {
            await _polylineAnnotationManager?.delete(_polylineAnnotation!);
          } catch (_) {}
          _polylineAnnotation = null;
        }
        MapUtils.showSnackBar(
          context,
          '🏁 تم إنهاء الرحلة التشغيلية.',
          isError: false,
        );
      }
    } catch (e) {
      MapUtils.log('❌ فشل إنهاء الرحلة: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          '❌ فشل إنهاء الرحلة على السيرفر.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingTrip = false);
    }
  }

  void disposeTripManager() {
    _polylineAnnotationManager = null;
    _polylineAnnotation = null;
    _currentOperationalRoute = null;
  }
}

class AssignedRouteChoice {
  final DriverLineAssignment assignment;
  final PlannedRoute route;
  final double distanceMeters;

  const AssignedRouteChoice({
    required this.assignment,
    required this.route,
    required this.distanceMeters,
  });
}
