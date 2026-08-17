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
import '../../widgets/admin_routes_search_sheet.dart';
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

  @override
  void dispose() {
    disposeMapDebug();
    _locationSubscription?.cancel();
    _adminLocationAnnotation = null;
    disposeAdminDrawRoute();
    disposePlannedRoutes();
    disposePickupPoints();
    disposeRoutes();
    disposePassengers();
    disposeDrivers();
    super.dispose();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted || isDrawingRoute) return;

    final driverId = findDriverIdByAnnotation(annotation);
    if (driverId != null) {
      final data = getDriverData(driverId);
      if (data != null) {
        unawaited(AdminDriverDetailsSheet.show(context, data));
      } else {
        _safeSnack('لا تتوفر بيانات هذا السائق حالياً', isError: true);
      }
      return;
    }

    final pickupId = _findId(pickupAnnotations, annotation);
    if (pickupId != null) _showPickupActionsSheet(pickupId);
  }

  String? _findId(Map<String, PointAnnotation> map, PointAnnotation a) {
    for (final e in map.entries) {
      if (e.value.id == a.id) return e.key;
    }
    return null;
  }

  void _startAddPickupPoint() {
    if (isDrawingRoute) {
      unawaited(cancelDrawingRoute());
    }
    setState(() => _isAddingPickupPoint = true);
    _safeSnack('📍 اضغط على الخريطة لتحديد موقع النقطة');
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

      if (position == null && !shown) {
        _safeSnack('⚠️ تعذر الحصول على الموقع. تأكد من تفعيل GPS',
            isError: true);
        return;
      }

      if (position != null) {
        await _showAdminLocation(
          position.latitude,
          position.longitude,
          moveCamera: true,
        );
      }

      if (!mounted) return;
      _safeSnack('📍 تم تحديد موقعك');
    } catch (e) {
      if (mounted) {
        _safeSnack('❌ تعذر تحديد الموقع', isError: true);
      }
      MapUtils.log('admin location: $e', tag: 'AdminMap');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _showAdminLocation(
    double lat,
    double lng, {
    required bool moveCamera,
  }) async {
    if (mapboxMap == null) return;

    if (moveCamera) {
      try {
        await mapboxMap!.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: 16.0,
            pitch: 0,
            bearing: 0,
          ),
        );
      } catch (_) {
        await flyToFlat(latitude: lat, longitude: lng, zoom: 16);
      }
    }

    final manager = pointAnnotationManager;
    if (manager == null) return;

    final point = Point(coordinates: Position(lng, lat));

    if (_adminLocationAnnotation != null) {
      _adminLocationAnnotation!.geometry = point;
      try {
        await manager.update(_adminLocationAnnotation!);
      } catch (_) {
        _adminLocationAnnotation = null;
      }
      if (_adminLocationAnnotation != null) return;
    }

    _adminMarkerBytes ??= await MapHelpers.createUserMarkerBytes();
    if (!mounted) return;

    try {
      _adminLocationAnnotation = await manager.create(
        PointAnnotationOptions(
          geometry: point,
          image: _adminMarkerBytes!,
          iconSize: 1.15,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (e) {
      MapUtils.log('admin marker: $e', tag: 'AdminMap');
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;

    final match = routes.where(
      (r) =>
          r.name.contains(query.trim()) ||
          r.startCity.contains(query.trim()) ||
          r.endCity.contains(query.trim()),
    );
    if (match.isNotEmpty) {
      onRouteFilterChanged(match.first.name);
      _safeSnack('🚌 تم اختيار المسار: ${match.first.name}');
      return;
    }

    final result = await _locationService.searchPlace(query);
    if (!mounted) return;

    if (result == null) {
      _safeSnack('⚠️ لم يتم العثور على المكان', isError: true);
      return;
    }

    await flyToFlat(
      latitude: result.latitude,
      longitude: result.longitude,
      zoom: 15,
    );
    if (!mounted) return;
    _safeSnack('🔎 تم الانتقال إلى ${result.name}');
  }

  Future<void> _handleMapTap(Point point) async {
    if (!_isAddingPickupPoint || !mounted) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    final userData = auth.userData;

    if (userId == null || userData == null) {
      _safeSnack('⚠️ يرجى تسجيل الدخول أولاً', isError: true);
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    final result = await showPickupPointPickerDialog(context: context);
    if (!mounted) return;

    if (result == null || result.name.trim().isEmpty) {
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    try {
      await _pickupManager.addPickupPoint(
        name: result.name.trim(),
        latitude: point.coordinates.lat.toDouble(),
        longitude: point.coordinates.lng.toDouble(),
        userId: userId,
        userType: userData.userType,
        pointType: result.pointType,
      );
      if (!mounted) return;
      _safeSnack('✅ تم إضافة النقطة');
    } catch (_) {
      _safeSnack('❌ فشل إضافة النقطة', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingPickupPoint = false);
    }
  }

  Future<void> _showPickupActionsSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted || point == null) return;

    final adderName = await PickupPointSheet.loadAdderName(point.addedBy);
    if (!mounted) return;

    final action = await PickupPointSheet.show(
      context: context,
      point: point,
      mode: PickupSheetMode.admin,
      adderName: adderName,
    );

    if (!mounted || action == null || action == PickupSheetAction.close) return;

    if (action == PickupSheetAction.edit) {
      if (!mounted) return;
      final updated = await showPickupPointPickerDialog(
        context: context,
        initialName: point.name,
        initialPointType: point.pointType,
      );
      if (updated == null || !mounted) return;
      await _pickupManager.updatePickupPoint(
        pointId: pickupId,
        data: {'name': updated.name.trim(), 'pointType': updated.pointType},
      );
      if (!mounted) return;
      _safeSnack('✅ تم تعديل النقطة');
    } else if (action == PickupSheetAction.delete) {
      await _pickupManager.deletePickupPoint(pointId: pickupId);
      if (!mounted) return;
      _safeSnack('🗑️ تم حذف النقطة');
    } else if (action == PickupSheetAction.approve) {
      await _pickupManager.updatePickupPoint(
        pointId: pickupId,
        data: {'status': 'approved'},
      );
      if (!mounted) return;
      _safeSnack('✅ تم اعتماد النقطة');
    } else if (action == PickupSheetAction.reject) {
      await _pickupManager.updatePickupPoint(
        pointId: pickupId,
        data: {'status': 'rejected'},
      );
      if (!mounted) return;
      _safeSnack('🚫 تم رفض النقطة');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        RepaintBoundary(
          child: MapWidget(
            key: const ValueKey('admin_map_widget'),
            textureView: true,
            onMapCreated: onMapCreated,
            onCameraChangeListener: onCameraChangedForDebug,
            // ignore: deprecated_member_use
            onTapListener: (event) {
              if (isDrawingRoute) {
                onDrawRouteMapTap(event.point);
              } else if (_isAddingPickupPoint) {
                _handleMapTap(event.point);
              } else {
                handleMapBackgroundTap(event);
              }
            },
            styleUri: MapCoreMixin.initialMapStyle,
          ),
        ),
        if (!isMapReady) const Center(child: CircularProgressIndicator()),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: ValueListenableBuilder<int>(
            valueListenable: routesUiTick,
            builder: (_, __, ___) {
              return SearchBarWidget(
                selectedRoute: selectedRouteName,
                routes: routeDropdownItems,
                onRouteChanged: onRouteFilterChanged,
                onSearchSubmitted: _searchPlace,
              );
            },
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
                onSearchRoutes: () {
                  AdminRoutesSearchSheet.show(
                    context,
                    onFocusRoute: (route) {
                      if (route.points.isEmpty) return;
                      final p = route.points[route.points.length ~/ 2];
                      unawaited(flyToFlat(
                        latitude: p.latitude,
                        longitude: p.longitude,
                        zoom: 13,
                      ));
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
