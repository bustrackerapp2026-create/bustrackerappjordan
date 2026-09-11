import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../map/map_core.dart';
import '../map/map_utils.dart';
import '../../driver/providers/driver_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../services/trip_service.dart';
import '../../services/route_plan_service.dart';
import '../../services/vehicle_trip_service.dart';
import '../../services/driver_line_assignment_service.dart';
import '../../models/trip_model.dart';
import '../../models/trip_status.dart';
import '../../models/route_point.dart';
import '../../models/planned_route.dart';

mixin TripManagerMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  bool _isProcessingTrip = false;
  String? _currentTripId;
  String? _currentVehicleTripId;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _polylineAnnotation;
  final TripService _tripService = TripService();
  final RoutePlanService _routePlanService = RoutePlanService();
  final VehicleTripService _vehicleTripService = VehicleTripService();
  final DriverLineAssignmentService _driverLineAssignmentService = DriverLineAssignmentService();

  bool get isProcessingTrip => _isProcessingTrip;
  String? get currentTripId => _currentTripId;
  String? get currentVehicleTripId => _currentVehicleTripId;

  Future<void> showRouteOnMap(List<RoutePoint> routePoints) async {
    if (_polylineAnnotationManager == null || routePoints.isEmpty) return;
    if (_polylineAnnotation != null) {
      await _polylineAnnotationManager?.delete(_polylineAnnotation!);
      _polylineAnnotation = null;
    }
    if (_polylineAnnotationManager == null) {
      _polylineAnnotationManager = await mapboxMap?.annotations.createPolylineAnnotationManager();
      if (_polylineAnnotationManager == null) return;
    }
    final positions = routePoints.map((p) => Position(p.longitude, p.latitude)).toList();
    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: positions),
      lineColor: Colors.blue.toARGB32(), lineWidth: 4.0, lineOpacity: 0.8,
    );
    _polylineAnnotation = await _polylineAnnotationManager?.create(options);
    MapUtils.log('✅ تم رسم المسار - عدد النقاط: ${routePoints.length}', tag: 'TripManager');
  }

  Future<List<PlannedRoute>> _approvedRoutesForLine(String lineName) async {
    final name = lineName.trim();
    if (name.isEmpty) return const [];
    final results = <PlannedRoute>[];
    for (final direction in RouteDirection.values) {
      final route = await _routePlanService.getLineDirection(lineName: name, direction: direction);
      if (route == null) continue;
      if (route.status != PlannedRouteStatus.approved) continue;
      if (route.points.length < 2) continue;
      results.add(route);
    }
    return results;
  }

  Future<PlannedRoute?> _resolveApprovedRoute(String lineName) async {
    final approved = await _approvedRoutesForLine(lineName);
    if (approved.isEmpty) {
      if (mounted) MapUtils.showSnackBar(context, '⚠️ لا يوجد مسار معتمد لهذا الخط حاليًا.', isError: true);
      return null;
    }
    if (approved.length == 1) return approved.first;
    if (!mounted) return null;
    return showDialog<PlannedRoute>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر اتجاه الرحلة'),
        content: const Text('لهذا الخط مساران معتمدان. اختر اتجاه الرحلة التشغيلية.'),
        actions: [
          for (final r in approved)
            TextButton(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(r.direction == RouteDirection.outbound ? 'ذهاب' : 'عودة'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
      ),
    );
  }

  /// مصدر الحقيقة للخط هو التعيين المعتمد للسائق.
  /// lineName القادم من الواجهة اختياري للتوافق، ولا يمكنه اختيار خط آخر.
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
    if (driverProvider.currentPosition == null) {
      MapUtils.showSnackBar(context, '⚠️ يرجى تحديد موقعك أولاً (اضغط على زر الموقع).', isError: true);
      return;
    }

    setState(() => _isProcessingTrip = true);
    try {
      // 1) اقرأ التعيين المعتمد للسائق، ولا تعتمد على lineName الحر من الواجهة.
      final assignment = await _driverLineAssignmentService.getApprovedForDriver(userId);
      final assignedLine = assignment == null
          ? null
          : await _driverLineAssignmentService.getApprovedLineForDriver(userId);

      if (assignment == null || assignedLine == null || !assignedLine.isApproved) {
        if (mounted) {
          MapUtils.showSnackBar(
            context,
            '⚠️ لا يوجد خط معتمد ومخصص لك. اطلب تعيين خط من الخطوط المعتمدة أولاً.',
            isError: true,
          );
        }
        return;
      }

      // 2) إن كانت الواجهة ترسل lineName، نتحقق فقط من تطابقه مع الخط المعيّن.
      final requestedLine = (lineName ?? '').trim();
      if (requestedLine.isNotEmpty && requestedLine != assignedLine.name.trim()) {
        if (mounted) {
          MapUtils.showSnackBar(
            context,
            '⚠️ الخط المختار لا يطابق الخط المعتمد والمخصص لك.',
            isError: true,
          );
        }
        return;
      }

      final resolvedLine = assignedLine.name.trim();
      if (resolvedLine.isEmpty) {
        if (mounted) {
          MapUtils.showSnackBar(context, '⚠️ تعيين الخط الخاص بك غير صالح حاليًا.', isError: true);
        }
        return;
      }

      // 3) ابحث فقط عن PlannedRoute تابع لاسم الخط المعتمد.
      final route = await _resolveApprovedRoute(resolvedLine);
      if (route == null || !mounted) return;

      // PlannedRoute الحالي لا يحتوي lineId، لذلك نتحقق من lineName بعد التطبيع.
      final routeLineName = route.lineName.trim();
      if (routeLineName != assignedLine.name.trim()) {
        MapUtils.showSnackBar(
          context,
          '⚠️ المسار المعتمد لا يتبع الخط المخصص لهذا السائق.',
          isError: true,
        );
        return;
      }

      final busNumber = authProvider.userData?.busNumber?.trim().isNotEmpty == true
          ? authProvider.userData!.busNumber!.trim()
          : '—';

      // 4) VehicleTrip أولاً — لا تفعيل محلي قبل نجاح Firestore.
      final vehicleTrip = await _vehicleTripService.startTrip(
        driverId: userId,
        busNumber: busNumber,
        routeId: route.id,
        direction: route.direction.firestoreValue,
      );
      if (!mounted) return;

      // 5) فقط بعد نجاح VehicleTrip.
      final started = driverProvider.startTrip(userId: userId);
      if (!started) {
        MapUtils.showSnackBar(
          context,
          '⚠️ تم إنشاء الرحلة التشغيلية لكن تعذر تفعيل الحالة المحلية.',
          isError: true,
        );
        setState(() => _currentVehicleTripId = vehicleTrip.id);
        return;
      }

      setState(() => _currentVehicleTripId = vehicleTrip.id);

      // منظومة trips القديمة تبقى انتقالية فقط.
      final docRef = FirebaseFirestore.instance.collection('trips').doc();
      final tripId = docRef.id;
      final trip = TripModel(
        id: tripId,
        passengerId: '',
        driverId: userId,
        pickupPoint: 'نقطة البداية',
        dropoffPoint: 'الوجهة',
        createdAt: DateTime.now(),
        status: TripStatus.active,
        notes: 'رحلة بدأها السائق',
        route: resolvedLine,
      );

      try {
        await _tripService.createTrip(trip);
        if (mounted) setState(() => _currentTripId = tripId);
      } catch (e) {
        MapUtils.log('⚠️ فشل إنشاء trips القديمة بعد VehicleTrip: $e', tag: 'TripManager');
      }

      if (!mounted) return;
      MapUtils.showSnackBar(context, '🚀 تم بدء الرحلة (${route.direction.labelAr})', isError: false);
    } on VehicleTripServiceException catch (e) {
      MapUtils.log('❌ VehicleTrip: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(context, e.message.isNotEmpty ? e.message : '❌ فشل بدء الرحلة التشغيلية.', isError: true);
      }
    } catch (e) {
      MapUtils.log('❌ فشل بدء الرحلة: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(context, '❌ فشل بدء الرحلة، يرجى المحاولة لاحقاً.', isError: true);
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

    final tripId = _currentTripId;
    final vehicleTripId = _currentVehicleTripId;
    setState(() => _isProcessingTrip = true);
    try {
      if (vehicleTripId != null && vehicleTripId.isNotEmpty) {
        await _vehicleTripService.completeTrip(tripId: vehicleTripId, driverId: driverId);
      }
      final route = driverProvider.endTrip(userId: driverId);
      if (tripId != null) {
        if (route.length > 5000) {
          throw Exception('عدد نقاط المسار (${route.length}) يتجاوز الحد الأقصى (5000).');
        }
        if (route.isNotEmpty) {
          await _tripService.updateTripStatus(tripId, TripStatus.completed, routePoints: route, driverId: driverId);
          if (!mounted) return;
          await showRouteOnMap(route);
          if (!mounted) return;
          MapUtils.showSnackBar(context, '🏁 تم إنهاء الرحلة وحفظ المسار (${route.length} نقطة).', isError: false);
        } else {
          await _tripService.updateTripStatus(tripId, TripStatus.completed, driverId: driverId);
          if (!mounted) return;
          MapUtils.showSnackBar(context, '🏁 تم إنهاء الرحلة (بدون مسار).', isError: false);
        }
      } else if (mounted) {
        MapUtils.showSnackBar(context, '🏁 تم إنهاء الرحلة محلياً.', isError: false);
      }
      if (mounted) {
        setState(() {
          _currentTripId = null;
          _currentVehicleTripId = null;
        });
      }
    } catch (e) {
      MapUtils.log('❌ فشل حفظ المسار: $e', tag: 'TripManager');
      if (mounted) MapUtils.showSnackBar(context, '❌ فشل حفظ بيانات الرحلة على السيرفر.', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingTrip = false);
    }
  }

  void disposeTripManager() {
    _polylineAnnotationManager = null;
    _polylineAnnotation = null;
  }
}
