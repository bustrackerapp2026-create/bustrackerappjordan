import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/pickup_point_sheet.dart';
import '../../../../core/location/location_permission_sheet.dart';
import '../../../../core/pickup/pickup_point_manager.dart';
import '../../../../core/pickup/pickup_point_dialog.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../services/location_service.dart';
import '../../../../map/widgets/search_bar_widget.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../widgets/admin_draw_route_banner.dart';
import '../../widgets/admin_driver_details_sheet.dart';
import '../../widgets/admin_map_fabs.dart';
import '../admin_dashboard.dart';
import 'mixins/driver_manager_mixin.dart';
import 'mixins/passenger_manager_mixin.dart';
import 'mixins/route_manager_mixin.dart';
import 'mixins/pickup_point_mixin.dart';
import 'mixins/admin_draw_route_mixin.dart';
import 'mixins/admin_planned_routes_mixin.dart';
import '../../widgets/admin_route_direction_filter.dart';

class AdminMapTab extends StatefulWidget {
  final AdminMapFocusRequest? focusRequest;
  const AdminMapTab({super.key, this.focusRequest});
  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab>
    with
        AutomaticKeepAliveClientMixin,
        MapCoreMixin<AdminMapTab>,
        DriverManagerMixin<AdminMapTab>,
        PassengerManagerMixin<AdminMapTab>,
        RouteManagerMixin<AdminMapTab>,
        PickupPointMixin<AdminMapTab>,
        AdminDrawRouteMixin<AdminMapTab>,
        AdminPlannedRoutesMixin<AdminMapTab> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final LocationService _locationService = LocationService();
  bool _isAddingPickupPoint = false;
  bool _isLoadingLocation = false;
  StreamSubscription? _locationSubscription;
  int? _lastHandledFocusToken;

  PointAnnotation? _adminLocationAnnotation;
  Uint8List? _adminMarkerBytes;

  @override
  bool get wantKeepAlive => true;

  @override
  bool get suppressPoiTap => _isAddingPickupPoint || isDrawingRoute;

  void _safeSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    MapUtils.showSnackBar(context, message, isError: isError);
  }

  @override
  void onStyleChanged() {
    _adminLocationAnnotation = null;
    redrawRoutes();
    unawaited(redrawPlannedRoutes());
    listenToPickupPoints();
    listenToActiveDrivers();
    listenToActivePassengers();
  }

  @override
  void didUpdateWidget(covariant AdminMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleFocusRequest();
  }

  @override
  void onMapCreated(MapboxMap map) {
    super.onMapCreated(map);
    unawaited(MapHelpers.createUserMarkerBytes().then((b) {
      _adminMarkerBytes = b;
    }));
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      listenToActiveDrivers();
      listenToActivePassengers();
      listenToRoutes();
      listenToPlannedRoutes();
      listenToPickupPoints();
      applyLabelLayersFilter();
      _scheduleFocusRequest();
    });
  }

  void _scheduleFocusRequest() {
    final focus = widget.focusRequest;
    if (focus == null || _lastHandledFocusToken == focus.token) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyFocusRequest(focus);
    });
  }

  void _applyFocusRequest(AdminMapFocusRequest focus) {
    if (_lastHandledFocusToken == focus.token || mapboxMap == null) return;
    _lastHandledFocusToken = focus.token;
    mapboxMap?.setCamera(CameraOptions(
      center: Point(coordinates: Position(focus.longitude, focus.latitude)),
      zoom: 16.5,
      pitch: 0,
      bearing: 0,
    ));
    _safeSnack('📍 تم التوجيه إلى: ${focus.pointName}');
  }

  Future<void> _showAdminLocation(
    double lat,
    double lng, {
    required bool moveCamera,
  }) async {
    if (mapboxMap == null || !mounted) return;

    if (moveCamera) {
      await flyToFlat(latitude: lat, longitude: lng, zoom: 16.0);
    }

    try {
      if (pointAnnotationManager == null) await initAnnotationManager();
      final manager = pointAnnotationManager;
      if (manager == null) return;

      if (_adminLocationAnnotation != null) {
        try {
          await manager.delete(_adminLocationAnnotation!);
        } catch (_) {}
        _adminLocationAnnotation = null;
      }

      _adminLocationAnnotation = await manager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconSize: 1.0,
          image: _adminMarkerBytes,
          iconColor: const Color(0xFF1565C0).toARGB32(),
        ),
      );
    } catch (e) {
      MapUtils.log('admin location marker: $e');
    }
  }

  void _startAddPickupPoint() {
    setState(() => _isAddingPickupPoint = true);
    _safeSnack('📍 انقر على الخريطة لاختيار موقع نقطة التجمع');
  }

  void _cancelAddPickupPoint() {
    setState(() => _isAddingPickupPoint = false);
    _safeSnack('❌ تم إلغاء إضافة النقطة', isError: true);
  }

  void _toggleDrawRoute() {
    if (isDrawingRoute) {
      unawaited(cancelDrawingRoute());
    } else {
      if (_isAddingPickupPoint) {
        setState(() => _isAddingPickupPoint = false);
      }
      startDrawingRoute();
    }
  }

  Future<void> _toggleRoutesVisibility() async {
    await togglePlannedRoutesVisibility();
    if (!mounted) return;
    _safeSnack(
      showPlannedRoutes
          ? '🚌 تم إظهار المسارات (${plannedRouteFilter.labelAr})'
          : '🙈 تم إخفاء المسارات',
    );
  }

  Future<void> _onRouteFilterChanged(AdminRouteDirectionFilter filter) async {
    await setPlannedRouteFilter(filter);
    if (!mounted) return;
    _safeSnack('عرض: ${filter.shortHint}');
  }

  Future<void> _goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;
    setState(() => _isLoadingLocation = true);

    try {
      final granted = await LocationPermissionSheet.ensurePermission(context);
      if (!mounted) return;
      if (!granted) {
        _safeSnack('⚠️ لم يتم منح صلاحية الموقع', isError: true);
        return;
      }

      var shown = false;

      final position = await _locationService.locateProgressive(
        quickTimeout: const Duration(seconds: 2),
        preciseTimeout: const Duration(seconds: 6),
        onProgress: (pos, stage) {
          if (!mounted) return;
          shown = true;
          unawaited(_showAdminLocation(
            pos.latitude,
            pos.longitude,
            moveCamera: true,
          ));
        },
      );

      if (!mounted) return;

      if (position != null) {
        await _showAdminLocation(
          position.latitude,
          position.longitude,
          moveCamera: !shown,
        );
        _safeSnack('📍 تم تحديد موقعك');
      } else if (!shown) {
        _safeSnack('⚠️ تعذر الحصول على الموقع', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _safeSnack('⚠️ خطأ في تحديد الموقع', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _onMapTap(MapContentGestureContext gesture) async {
    if (!mounted) return;

    if (isDrawingRoute) {
      await onDrawRouteMapTap(gesture.point);
      return;
    }

    if (_isAddingPickupPoint) {
      final point = gesture.point;
      final lat = point.coordinates.lat.toDouble();
      final lng = point.coordinates.lng.toDouble();

      final auth = context.read<AuthProvider>();
      final adminId = auth.userId;
      if (adminId == null) {
        _safeSnack('يجب تسجيل الدخول', isError: true);
        return;
      }

      final result = await PickupPointDialog.show(
        context,
        latitude: lat,
        longitude: lng,
      );
      if (result == null || !mounted) return;

      try {
        await _pickupManager.addPickupPoint(
          name: result.name,
          latitude: lat,
          longitude: lng,
          createdBy: adminId,
          capacity: result.capacity,
          notes: result.notes,
        );
        if (!mounted) return;
        setState(() => _isAddingPickupPoint = false);
        _safeSnack('✅ تمت إضافة نقطة التجمع');
      } catch (e) {
        _safeSnack('فشل إضافة النقطة', isError: true);
      }
      return;
    }

    await handleMapBackgroundTap(gesture);
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    // تفويض للخلطات حسب نوع العلامة إن وُجدت
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    disposePlannedRoutes();
    disposeAdminDrawRoute();
    disposeMapDebug();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: MapWidget(
              key: const ValueKey('admin_map'),
              styleUri: currentMapStyle,
              textureView: true,
              onMapCreated: onMapCreated,
              onCameraChangeListener: onCameraChangedForDebug,
              onTapListener: (gesture) {
                unawaited(_onMapTap(gesture));
              },
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: SearchBarWidget(
              onPlaceSelected: (lat, lng, name) {
                unawaited(flyToFlat(latitude: lat, longitude: lng, zoom: 15.5));
              },
            ),
          ),
        ),
        if (isDrawingRoute)
          Positioned(
            top: 72,
            left: 16,
            right: 16,
            child: AdminDrawRouteBanner(
              drawPointCount: drawPointCount,
              isSnappingSegment: isSnappingSegment,
              onSave: drawPointCount >= 2 && !isSnappingSegment
                  ? finishAndSaveDrawnRoute
                  : null,
              onUndo: isSnappingSegment ? null : undoLastDrawPoint,
              onCancel: cancelDrawingRoute,
            ),
          ),
        Positioned.fill(
          child: ValueListenableBuilder<int>(
            valueListenable: plannedRoutesUiTick,
            builder: (_, __, ___) {
              return AdminMapFabs(
                showPassengers: showPassengers,
                showRoutes: showPlannedRoutes,
                isAddingPickupPoint: _isAddingPickupPoint,
                isDrawingRoute: isDrawingRoute,
                isLoadingLocation: _isLoadingLocation,
                routeFilter: plannedRouteFilter,
                outboundCount: outboundRoutesCount,
                returnCount: returnRoutesCount,
                onTogglePassengers: togglePassengersVisibility,
                onToggleRoutes: () => unawaited(_toggleRoutesVisibility()),
                onRouteFilterChanged: (f) =>
                    unawaited(_onRouteFilterChanged(f)),
                onTogglePickup: _isAddingPickupPoint
                    ? _cancelAddPickupPoint
                    : _startAddPickupPoint,
                onToggleDrawRoute: _toggleDrawRoute,
                onMyLocation: _goToMyLocation,
                onMapLayers: () => showMapSettingsSheet(context),
              );
            },
          ),
        ),
      ],
    );
  }
}
