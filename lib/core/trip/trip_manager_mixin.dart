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
import '../../models/trip_model.dart';
import '../../models/trip_status.dart';
import '../../models/route_point.dart';

mixin TripManagerMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  bool _isProcessingTrip = false;
  String? _currentTripId;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _polylineAnnotation;
  final TripService _tripService = TripService();

  bool get isProcessingTrip => _isProcessingTrip;
  String? get currentTripId => _currentTripId;

  Future<void> showRouteOnMap(List<RoutePoint> routePoints) async {
    if (_polylineAnnotationManager == null || routePoints.isEmpty) return;

    if (_polylineAnnotation != null) {
      await _polylineAnnotationManager?.delete(_polylineAnnotation!);
      _polylineAnnotation = null;
    }

    if (_polylineAnnotationManager == null) {
      _polylineAnnotationManager =
          await mapboxMap?.annotations.createPolylineAnnotationManager();
      if (_polylineAnnotationManager == null) return;
    }

    final positions =
        routePoints.map((p) => Position(p.longitude, p.latitude)).toList();

    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: positions),
      lineColor: Colors.blue.toARGB32(),
      lineWidth: 4.0,
      lineOpacity: 0.8,
    );

    _polylineAnnotation = await _polylineAnnotationManager?.create(options);
    MapUtils.log('✅ تم رسم المسار - عدد النقاط: ${routePoints.length}',
        tag: 'TripManager');
  }

  Future<void> startTrip() async {
    if (_isProcessingTrip) return;
    if (!mounted) return;

    final driverProvider = context.read<DriverProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;

    if (!driverProvider.isOnline) {
      MapUtils.showSnackBar(context, '⚠️ يجب أن تكون متاحاً أولاً.',
          isError: true);
      return;
    }
    if (driverProvider.isTripActive) {
      MapUtils.showSnackBar(context, '⚠️ الرحلة مفعلة بالفعل.', isError: true);
      return;
    }
    if (userId == null) {
      MapUtils.showSnackBar(context, '⚠️ يرجى تسجيل الدخول أولاً.',
          isError: true);
      return;
    }
    if (driverProvider.currentPosition == null) {
      MapUtils.showSnackBar(
          context, '⚠️ يرجى تحديد موقعك أولاً (اضغط على زر الموقع).',
          isError: true);
      return;
    }

    setState(() => _isProcessingTrip = true);

    try {
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
      );

      await _tripService.createTrip(trip);

      if (!mounted) return;

      setState(() => _currentTripId = tripId);
      driverProvider.startTrip();
      MapUtils.showSnackBar(context, '🚀 تم بدء الرحلة!', isError: false);
    } catch (e) {
      MapUtils.log('❌ فشل إنشاء الرحلة: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(
            context, '❌ فشل بدء الرحلة، يرجى المحاولة لاحقاً.',
            isError: true);
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

    if (!driverProvider.isTripActive) {
      MapUtils.showSnackBar(context, '⚠️ لا توجد رحلة نشطة.', isError: true);
      return;
    }
    if (_currentTripId == null) {
      MapUtils.showSnackBar(context, '⚠️ لا توجد رحلة نشطة للحفظ.',
          isError: true);
      return;
    }
    if (driverId == null) {
      MapUtils.showSnackBar(context, '⚠️ يرجى تسجيل الدخول أولاً.',
          isError: true);
      return;
    }

    final tripId = _currentTripId!;
    setState(() => _isProcessingTrip = true);

    final route = driverProvider.endTrip();

    try {
      if (route.length > 5000) {
        throw Exception(
            'عدد نقاط المسار (${route.length}) يتجاوز الحد الأقصى (5000).');
      }

      if (route.isNotEmpty) {
        await _tripService.updateTripStatus(
          tripId,
          TripStatus.completed,
          routePoints: route,
          driverId: driverId,
        );

        if (!mounted) return;

        await showRouteOnMap(route);

        if (!mounted) return;
        MapUtils.showSnackBar(
            context, '🏁 تم إنهاء الرحلة وحفظ المسار (${route.length} نقطة).',
            isError: false);
      } else {
        await _tripService.updateTripStatus(
          tripId,
          TripStatus.completed,
          driverId: driverId,
        );
        if (!mounted) return;
        MapUtils.showSnackBar(context, '🏁 تم إنهاء الرحلة (بدون مسار).',
            isError: false);
      }

      if (mounted) {
        setState(() => _currentTripId = null);
      }
    } catch (e) {
      MapUtils.log('❌ فشل حفظ المسار: $e', tag: 'TripManager');
      if (mounted) {
        MapUtils.showSnackBar(context, '❌ فشل حفظ بيانات الرحلة على السيرفر.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessingTrip = false);
    }
  }

  void disposeTripManager() {
    _polylineAnnotationManager = null;
    _polylineAnnotation = null;
  }
}
