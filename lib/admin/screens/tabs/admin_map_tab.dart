import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/pickup_point_sheet.dart';
import '../../../../core/pickup/pickup_point_manager.dart';
import '../../../../core/pickup/pickup_point_dialog.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../services/location_service.dart';
import '../../../../services/route_seed_service.dart';
import '../../../../map/widgets/search_bar_widget.dart';
import '../admin_dashboard.dart';
import 'mixins/driver_manager_mixin.dart';
import 'mixins/passenger_manager_mixin.dart';
import 'mixins/route_manager_mixin.dart';
import 'mixins/pickup_point_mixin.dart';

class AdminMapTab extends StatefulWidget {
  final AdminMapFocusRequest? focusRequest;
  const AdminMapTab({super.key, this.focusRequest});
  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab>
    with
        MapCoreMixin<AdminMapTab>,
        DriverManagerMixin<AdminMapTab>,
        PassengerManagerMixin<AdminMapTab>,
        RouteManagerMixin<AdminMapTab>,
        PickupPointMixin<AdminMapTab> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final LocationService _locationService = LocationService();
  bool _isAddingPickupPoint = false;
  bool _isLoadingLocation = false;
  bool _isSeeding = false;
  StreamSubscription<Position>? _locationSubscription;
  int? _lastHandledFocusToken;

  @override
  bool get suppressPoiTap => _isAddingPickupPoint;

  void _safeSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    MapUtils.showSnackBar(context, message, isError: isError);
  }

  @override
  void onStyleChanged() {
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
    Future<void>.delayed(const Duration(milliseconds: 450), () {
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
    _locationSubscription?.cancel();
    disposePickupPoints();
    disposeRoutes();
    disposePassengers();
    disposeDrivers();
    super.dispose();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;
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
    setState(() => _isAddingPickupPoint = true);
    _safeSnack('📍 اضغط على الخريطة لتحديد موقع النقطة');
  }

  void _cancelAddPickupPoint() {
    setState(() => _isAddingPickupPoint = false);
    _safeSnack('❌ تم إلغاء إضافة النقطة', isError: true);
  }

  Future<void> _goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      final hasPermission =
          await _locationService.checkAndRequestPermission();
      if (!mounted) return;

      if (!hasPermission) {
        _safeSnack('⚠️ يرجى تفعيل الموقع أولاً', isError: true);
        return;
      }

      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;

      if (position == null) {
        _safeSnack('⚠️ تعذر الحصول على الموقع', isError: true);
        return;
      }

      await flyToFlat(
        latitude: position.latitude,
        longitude: position.longitude,
        zoom: 15,
      );
      if (!mounted) return;
      _safeSnack('📍 تم تحديد موقعك الحالي');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;

    // ابحث أولاً ضمن أسماء المسارات المحمّلة
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
      // أعد الاستماع لإجبار إعادة التحميل والرسم
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
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('admin_map_widget'),
          onMapCreated: onMapCreated,
          // ignore: deprecated_member_use
          onTapListener: (event) {
            if (_isAddingPickupPoint) {
              _handleMapTap(event.point);
            } else {
              handleMapBackgroundTap(event);
            }
          },
          styleUri: currentMapStyle,
        ),
        if (!isMapReady) const Center(child: CircularProgressIndicator()),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SearchBarWidget(
            selectedRoute: selectedRouteName,
            routes: routeDropdownItems,
            onRouteChanged: onRouteFilterChanged,
            onSearchSubmitted: _searchPlace,
          ),
        ),
        // زر زرع المسارات — ظاهر مباشرة على الخريطة
        Positioned(
          top: 72,
          left: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isSeeding ? null : _seedRoutesFromMap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      Icon(Icons.route, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      routes.isEmpty ? 'زرع مسارات الأردن' : 'تحديث المسارات',
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
