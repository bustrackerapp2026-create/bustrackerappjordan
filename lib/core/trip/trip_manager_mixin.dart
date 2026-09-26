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
import '../../services/vehicle_trip_service.dart';
import '../../services/driver_line_assignment_service.dart';
import '../../services/vehicle_operational_session_service.dart';
import '../../driver/services/driver_tracking_hub.dart';
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
  final VehicleTripService _vehicleTripService = VehicleTripService();
  final DriverLineAssignmentService _driverLineAssignmentService =
      DriverLineAssignmentService();
  final VehicleOperationalSessionService _vehicleSession =
      VehicleOperationalSessionService();
  final DriverTrackingHub _trackingHub = DriverTrackingHub.instance;

  static const double _routeStartMatchMaxMeters = 750.0;

  bool get isProcessingTrip => _isProcessingTrip;
  String? get currentTripId => _currentTripId;
  String? get currentVehicleTripId => _currentVehicleTripId;
  PlannedRoute? get currentOperationalRoute => _currentOperationalRoute;

  Future<void> showRouteOnMap(List<RoutePoint> routePoints) async {
    if (routePoints.isEmpty) return;
    if (mapboxMap == null) return;

    _polylineAnnotationManager ??=
        await mapboxMap!.annotations.createPolylineAnnotationManager();

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

  /// يستعيد الرحلة التشغيلية والمسار المعتمد عند إعادة فتح الشاشة.
  /// تحفظ الحالة داخل هذا الـmixin لأن معرف الرحلة والمسار حقول خاصة به.
  Future<void> restoreActiveVehicleTripRoute(String driverId) async {
    final uid = driverId.trim();
    if (!mounted || uid.isEmpty) return;

    try {
      final activeTrip = await _vehicleTripService.findActiveTripForDriver(uid);
      if (activeTrip == null || !activeTrip.isActive) return;

      final routeId = activeTrip.routeId.trim();
      if (routeId.isEmpty) return;

      final snap = await FirebaseFirestore.instance
          .collection('plannedRoutes')
          .doc(routeId)
          .get();

      if (!snap.exists || snap.data() == null) {
        MapUtils.log(
          '⚠️ المسار التشغيلي غير موجود: $routeId',
          tag: 'TripManager',
        );
        return;
      }

      final route = PlannedRoute.fromDoc(snap.id, snap.data()!);
      if (!route.isApproved || route.points.length < 2) {
        MapUtils.log(
          '⚠️ المسار التشغيلي غير صالح أو غير معتمد: ${route.id}',
          tag: 'TripManager',
        );
        return;
      }

      if (route.direction.firestoreValue != activeTrip.direction) {
        MapUtils.log(
          '⚠️ اتجاه الرحلة لا يطابق اتجاه المسار: ${route.id}',
          tag: 'TripManager',
        );
        return;
      }

      if (!mounted) return;
      _currentVehicleTripId = activeTrip.id;
      _currentOperationalRoute = route;
      _trackingHub.setActiveVehicleTrip(
        activeTrip.id,
        routeId: activeTrip.routeId,
        direction: activeTrip.direction,
      );

      await showRouteOnMap(route.points);
    } catch (e, st) {
      MapUtils.log(
        '❌ فشل استعادة المسار التشغيلي بعد إعادة الدخول: $e',
        tag: 'TripManager',
      );
      debugPrint(st.toString());
    }
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
    geo.Position currentPosition, {
    String? busNumber,
  }) async {
    final operationalBus = busNumber?.trim() ?? '';

    // المصدر التشغيلي للمسار هو المركبة. هذا يسمح لعدة سائقين مسجلين
    // على نفس الباص باستخدام نفس التعيين المعتمد.
    List<DriverLineAssignment> assignments;
    if (operationalBus.isNotEmpty) {
      assignments = await _driverLineAssignmentService
          .getApprovedAssignmentsForVehicle(
        operationalBus,
        limit: 50,
      );

      // توافق رجعي مع السجلات القديمة التي لا تحتوي busNumber.
      if (assignments.isEmpty) {
        final driverAssignments =
            await _driverLineAssignmentService.getApprovedAssignmentsForDriver(
          driverId,
          limit: 50,
        );
        assignments = driverAssignments
            .where((assignment) => assignment.busNumber.trim().isEmpty)
            .toList();
      }
    } else {
      assignments = await _driverLineAssignmentService
          .getApprovedAssignmentsForDriver(
        driverId,
        limit: 50,
      );
    }

    final candidates = <AssignedRouteChoice>[];
    for (final assignment in assignments) {
      if (operationalBus.isNotEmpty &&
          assignment.busNumber.trim().isNotEmpty &&
          assignment.busNumber.trim() != operationalBus) {
        continue;
      }

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
    if (best.distanceMeters > _routeStartMatchMaxMeters) {
      return null;
    }
    return best;
  }

  Future<bool> isNearAssignedRouteStart(
    String driverId,
    geo.Position currentPosition,
  ) async {
    final busNumber =
        context.read<AuthProvider>().userData?.busNumber?.trim();
    final resolved = await _resolveAssignedRoute(
      driverId,
      currentPosition,
      busNumber: busNumber,
    );
    return resolved != null;
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
      final busNumber =
          authProvider.userData?.busNumber?.trim().isNotEmpty == true
              ? authProvider.userData!.busNumber!.trim()
              : '';

      if (busNumber.isEmpty) {
        MapUtils.showSnackBar(
          context,
          '⚠️ لا يوجد رقم باص/سرفيس مسجل لهذا الحساب.',
          isError: true,
        );
        return;
      }

      final resolved = await _resolveAssignedRoute(
        userId,
        currentPosition,
        busNumber: busNumber,
      );

      if (resolved == null) {
        List<DriverLineAssignment> vehicleAssignments =
            await _driverLineAssignmentService.getApprovedAssignmentsForVehicle(
          busNumber,
          limit: 50,
        );

        if (vehicleAssignments.isEmpty) {
          final driverAssignments =
              await _driverLineAssignmentService.getApprovedAssignmentsForDriver(
            userId,
            limit: 50,
          );
          vehicleAssignments = driverAssignments
              .where((assignment) => assignment.busNumber.trim().isEmpty)
              .toList();
        }

        if (vehicleAssignments.isEmpty) {
          if (mounted) {
            MapUtils.showSnackBar(
              context,
              '⚠️ لا يوجد مسار معتمد ومخصص لك. اطلب تعيين مسار من الأدمن أولاً.',
              isError: true,
            );
          }
        } else {
          final validAssignments = <DriverLineAssignment>[];
          for (final assignment in vehicleAssignments) {
            final route = await _getApprovedRouteForAssignment(
              assignment.routeId,
              assignment.lineId,
            );
            if (route != null) validAssignments.add(assignment);
          }

          if (validAssignments.isEmpty) {
            if (mounted) {
              MapUtils.showSnackBar(
                context,
                '⚠️ المسار المخصص لك غير صالح أو غير مرتبط بالخط التشغيلي المعتمد.',
                isError: true,
              );
            }
          } else {
            final message = validAssignments.length == 1
                ? '⚠️ أنت بعيد عن نقطة بداية المسار المخصص لك. اقترب من نقطة البداية (بحد أقصى 750م) ثم ابدأ الرحلة.'
                : '⚠️ أنت بعيد عن نقاط بداية المسارات المخصصة لك. ابدأ من نقطة بداية الذهاب أو نقطة بداية الإياب ضمن 750م.';
            if (mounted) {
              MapUtils.showSnackBar(context, message, isError: true);
            }
          }
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

      // إعادة التحقق من ملكية المركبة قبل إنشاء الرحلة التشغيلية.
      await _vehicleSession.claimOrRefresh(
        driverId: userId,
        busNumber: busNumber,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
      );

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

      try {
        final sessionOwned = await _vehicleSession.setTripActive(
          driverId: userId,
          busNumber: busNumber,
          isTripActive: true,
          tripId: vehicleTrip.id,
        );
        if (!sessionOwned) {
          throw const VehicleOperationalSessionException(
            'فقد حسابك ملكية المركبة قبل تفعيل الرحلة. لم يتم اعتماد الرحلة.',
            code: 'vehicle-session-lost',
          );
        }
      } catch (_) {
        try {
          await _vehicleTripService.cancelTrip(
            tripId: vehicleTrip.id,
            driverId: userId,
          );
        } catch (rollbackError) {
          MapUtils.log(
            '❌ فشل إلغاء VehicleTrip بعد فقد جلسة المركبة: $rollbackError',
            tag: 'TripManager',
          );
        }
        rethrow;
      }

      if (!mounted) return;

      final started = driverProvider.startTrip(userId: userId);
      if (!started) {
        try {
          await _vehicleTripService.cancelTrip(
            tripId: vehicleTrip.id,
            driverId: userId,
          );
        } catch (rollbackError, rollbackStack) {
          MapUtils.log(
            '❌ فشل التراجع عن الرحلة التشغيلية بعد فشل التفعيل المحلي: $rollbackError\n$rollbackStack',
            tag: 'TripManager',
          );
        }

        if (mounted) {
          setState(() {
            _currentVehicleTripId = null;
            _currentOperationalRoute = null;
          });
          MapUtils.showSnackBar(
            context,
            '⚠️ تعذر تفعيل الرحلة محليًا، وتمت محاولة إلغاء الرحلة التشغيلية.',
            isError: true,
          );
        }
        return;
      }

      setState(() {
        _currentVehicleTripId = vehicleTrip.id;
        _currentOperationalRoute = route;
      });
      _trackingHub.setActiveVehicleTrip(
        vehicleTrip.id,
        routeId: vehicleTrip.routeId,
        direction: vehicleTrip.direction,
      );

      await showRouteOnMap(route.points);

      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        '🚀 تم بدء رحلة ${route.direction.labelAr} على المسار المخصص: ${resolvedLine.isEmpty ? '—' : resolvedLine}',
        isError: false,
      );
    } on VehicleOperationalSessionException catch (e) {
      MapUtils.log('❌ VehicleSession: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          e.message,
          isError: true,
        );
      }
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

    setState(() => _isProcessingTrip = true);
    try {
      var vehicleTripId = _currentVehicleTripId;

      // بعد إعادة فتح التطبيق/تسجيل الدخول قد تكون الرحلة التشغيلية
      // مستعادة من Firestore بينما فقدت الشاشة المعرّف المحلي لها.
      // في هذه الحالة نستعيد المعرّف الحقيقي قبل الإنهاء حتى لا يبقى
      // VehicleTrip والقفل التشغيلي عالقين في حالة ACTIVE.
      if (vehicleTripId == null || vehicleTripId.isEmpty) {
        final activeVehicleTrip =
            await _vehicleTripService.findActiveTripForDriver(driverId);
        vehicleTripId = activeVehicleTrip?.id;
      }

      if (vehicleTripId != null && vehicleTripId.isNotEmpty) {
        // يجب رفع أي TripPings متبقية قبل تحويل VehicleTrip إلى حالة نهائية،
        // لأن Rules تسمح بالكتابة التاريخية أثناء الرحلة النشطة فقط.
        await _trackingHub.flushHistoricalTripPings(force: true);

        await _vehicleTripService.completeTrip(
          tripId: vehicleTripId,
          driverId: driverId,
        );
      }
      _trackingHub.clearActiveVehicleTrip();

      final busNumber = authProvider.userData?.busNumber?.trim() ?? '';
      if (busNumber.isNotEmpty) {
        final sessionOwned = await _vehicleSession.setTripActive(
          driverId: driverId,
          busNumber: busNumber,
          isTripActive: false,
        );
        if (!sessionOwned) {
          throw const VehicleOperationalSessionException(
            'تم إنهاء الرحلة لكن تعذر تحرير حالة الرحلة داخل جلسة المركبة. أعد المحاولة لتأكيد تحرير المركبة.',
            code: 'vehicle-session-sync-failed',
          );
        }
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
        if (!mounted) return;
        MapUtils.showSnackBar(
          context,
          '🏁 تم إنهاء الرحلة التشغيلية.',
          isError: false,
        );
      }
    } on VehicleOperationalSessionException catch (e) {
      MapUtils.log('❌ VehicleSession endTrip: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          e.message,
          isError: true,
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
