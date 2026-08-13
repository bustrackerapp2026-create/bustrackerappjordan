import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/pickup_point_sheet.dart';
import '../../../../core/location/location_permission_sheet.dart';
import '../../../../core/pickup/pickup_point_manager.dart';
import '../../../../core/pickup/pickup_point_dialog.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../services/location_service.dart';
import '../../../../services/route_seed_service.dart';
import '../../../../map/widgets/search_bar_widget.dart';
import '../../../../map/utils/map_helpers.dart';
import '../admin_dashboard.dart';
import 'mixins/driver_manager_mixin.dart';
import 'mixins/passenger_manager_mixin.dart';
import 'mixins/route_manager_mixin.dart';
import 'mixins/pickup_point_mixin.dart';
import 'mixins/admin_draw_route_mixin.dart';

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
        AdminDrawRouteMixin<AdminMapTab> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final LocationService _locationService = LocationService();
  bool _isAddingPickupPoint = false;
  bool _isLoadingLocation = false;
  bool _isSeeding = false;
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
    disposePickupPoints();
    disposeRoutes();
    disposePassengers();
    disposeDrivers();
    super.dispose();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted || isDrawingRoute) return;
    final driverId = _findId(driverAnnotations, annotation);
    if (driverId != null) {
      _safeSnack('🔄 جاري تحميل بيانات السائق (ID: $driverId)...');
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
        _safeSnack('⚠️ تعذر الحصول على الموقع. تأكد من تفعيل GPS', isError: true);
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

  Future<void> _seedRoutesFromMap() async {
    if (_isSeeding) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زرع مسارات الأردن'),
        content: const Text(
          'سيتم إضافة 8 خطوط بين المحافظات إلى Firestore ثم عرضها على الخريطة.\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('زرع'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSeeding = true);
    try {
      final msg = await RouteSeedService().seedJordanDemoRoutes();
      if (!mounted) return;
      _safeSnack('✅ $msg');
      listenToRoutes();
    } catch (e) {
      if (!mounted) return;
      _safeSnack('❌ فشل الزرع: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
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
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF5F3FF),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'رسم مسار · $drawPointCount نقطة — انقر على الخريطة',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6D28D9),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: drawPointCount >= 2
                                ? finishAndSaveDrawnRoute
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('حفظ وتسمية'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: undoLastDrawPoint,
                          child: const Text('تراجع'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: cancelDrawingRoute,
                          child: const Text('إلغاء'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Positioned(
            top: 72,
            left: 16,
            child: ValueListenableBuilder<int>(
              valueListenable: routesUiTick,
              builder: (_, __, ___) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isSeeding ? null : _seedRoutesFromMap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSeeding)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(Icons.route,
                                color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            routes.isEmpty
                                ? 'زرع مسارات الأردن'
                                : 'تحديث المسارات',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          if (routes.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${routes.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Positioned(
          bottom: 30,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'admin_passengers_toggle',
            onPressed: togglePassengersVisibility,
            backgroundColor:
                showPassengers ? Colors.blue.shade700 : Colors.grey,
            foregroundColor: Colors.white,
            child: Icon(showPassengers ? Icons.person : Icons.person_off),
          ),
        ),
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_add_pickup',
            onPressed: _isAddingPickupPoint
                ? _cancelAddPickupPoint
                : _startAddPickupPoint,
            backgroundColor: _isAddingPickupPoint ? Colors.red : Colors.orange,
            foregroundColor: Colors.white,
            child: Icon(
              _isAddingPickupPoint ? Icons.close : Icons.add_location,
            ),
          ),
        ),
        Positioned(
          bottom: 180,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_draw_route',
            onPressed: _toggleDrawRoute,
            backgroundColor:
                isDrawingRoute ? const Color(0xFF7C3AED) : Colors.white,
            foregroundColor:
                isDrawingRoute ? Colors.white : const Color(0xFF7C3AED),
            child: Icon(
              isDrawingRoute ? Icons.close : Icons.timeline_rounded,
            ),
          ),
        ),
        Positioned(
          bottom: 260,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_location_fab',
            onPressed: _goToMyLocation,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryColor,
            elevation: 4,
            shape: const CircleBorder(),
            child: _isLoadingLocation
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
        Positioned(
          bottom: 30,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_layers_fab',
            onPressed: () => showMapSettingsSheet(context),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textColor,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.layers_rounded, size: 26),
          ),
        ),
      ],
    );
  }
}
