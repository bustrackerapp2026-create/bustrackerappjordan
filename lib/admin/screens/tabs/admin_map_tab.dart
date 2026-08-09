import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/pickup/pickup_point_manager.dart';
import '../../../../core/pickup/pickup_point_dialog.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../services/location_service.dart';
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
  StreamSubscription<Position>? _locationSubscription;
  int? _lastHandledFocusToken;

  @override
  bool get suppressPoiTap => _isAddingPickupPoint;

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
    if (mounted) {
      MapUtils.showSnackBar(context, '📍 تم التوجيه إلى: ${focus.pointName}');
    }
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
      MapUtils.showSnackBar(
          context, '🔄 جاري تحميل بيانات السائق (ID: $driverId)...');
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

  String _userTypeLabel(String type) {
    switch (type) {
      case 'driver':
        return 'سائق';
      case 'passenger':
        return 'راكب';
      case 'admin':
        return 'أدمن';
      default:
        return type;
    }
  }

  Future<String> _loadAdderName(String userId) async {
    if (userId.isEmpty) return 'غير معروف';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final name = doc.data()?['fullName'] as String?;
      return (name != null && name.trim().isNotEmpty) ? name.trim() : 'بدون اسم';
    } catch (_) {
      return 'تعذر جلب الاسم';
    }
  }

  void _startAddPickupPoint() {
    setState(() => _isAddingPickupPoint = true);
    MapUtils.showSnackBar(context, '📍 اضغط على الخريطة لتحديد موقع النقطة');
  }

  void _cancelAddPickupPoint() {
    setState(() => _isAddingPickupPoint = false);
    MapUtils.showSnackBar(context, '❌ تم إلغاء إضافة النقطة', isError: true);
  }

  Future<void> _goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      if (!await _locationService.checkAndRequestPermission()) {
        if (mounted) {
          MapUtils.showSnackBar(context, '⚠️ يرجى تفعيل الموقع أولاً',
              isError: true);
        }
        return;
      }
      final position = await _locationService.getCurrentPosition();
      if (!mounted || position == null) {
        if (mounted) {
          MapUtils.showSnackBar(context, '⚠️ تعذر الحصول على الموقع',
              isError: true);
        }
        return;
      }
      await flyToFlat(
        latitude: position.latitude,
        longitude: position.longitude,
        zoom: 15,
      );
      if (mounted) MapUtils.showSnackBar(context, '📍 تم تحديد موقعك الحالي');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    final result = await _locationService.searchPlace(query);
    if (!mounted) return;
    if (result == null) {
      MapUtils.showSnackBar(context, '⚠️ لم يتم العثور على المكان',
          isError: true);
      return;
    }
    await flyToFlat(
      latitude: result.latitude,
      longitude: result.longitude,
      zoom: 15,
    );
    MapUtils.showSnackBar(context, '🔎 تم الانتقال إلى ${result.name}');
  }

  Future<void> _handleMapTap(Point point) async {
    if (!_isAddingPickupPoint || !mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.userId == null || auth.userData == null) {
      MapUtils.showSnackBar(context, '⚠️ يرجى تسجيل الدخول أولاً',
          isError: true);
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
        userId: auth.userId!,
        userType: auth.userData!.userType,
        pointType: result.pointType,
      );
      if (mounted) MapUtils.showSnackBar(context, '✅ تم إضافة النقطة');
    } catch (_) {
      if (mounted) {
        MapUtils.showSnackBar(context, '❌ فشل إضافة النقطة', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isAddingPickupPoint = false);
    }
  }

  Future<void> _showPickupActionsSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted || point == null) return;
    final adderFuture = _loadAdderName(point.addedBy);
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FutureBuilder<String>(
        future: adderFuture,
        builder: (_, snap) {
          final count = point.confirmationCount;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(point.pointType == 'passenger'
                      ? '🚶 تجمع ركاب'
                      : '🚌 تجمع باصات'),
                  const SizedBox(height: 12),
                  Text('أكدها $count',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      'أضافها: ${snap.data ?? '...'} · ${_userTypeLabel(point.addedByUserType)}'),
                  ListTile(
                      title: const Text('تعديل'),
                      onTap: () => Navigator.pop(ctx, 'edit')),
                  ListTile(
                      title: const Text('حذف'),
                      onTap: () => Navigator.pop(ctx, 'delete')),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
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
      if (mounted) MapUtils.showSnackBar(context, '✅ تم تعديل النقطة');
    } else if (action == 'delete') {
      await _pickupManager.deletePickupPoint(pointId: pickupId);
      if (mounted) MapUtils.showSnackBar(context, '🗑️ تم حذف النقطة');
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
            selectedRoute: 'الكل',
            routes: const ['الكل'],
            onRouteChanged: (_) {},
            onSearchSubmitted: _searchPlace,
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
