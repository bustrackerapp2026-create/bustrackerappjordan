import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/pickup/pickup_point_manager.dart';
import '../../../../core/pickup/pickup_point_dialog.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import 'mixins/driver_manager_mixin.dart';
import 'mixins/passenger_manager_mixin.dart';
import 'mixins/route_manager_mixin.dart';
import 'mixins/pickup_point_mixin.dart';

class AdminMapTab extends StatefulWidget {
  const AdminMapTab({super.key});

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
  bool _isAddingPickupPoint = false;

  @override
  void initState() {
    super.initState();
    _initializeMapFeatures();
  }

  void _initializeMapFeatures() {
    MapUtils.log('✅ AdminMapTab: بدء تهيئة ميزات الخريطة', tag: 'AdminMap');
    listenToActiveDrivers();
    listenToActivePassengers();
    listenToRoutes();
    listenToPickupPoints();
    MapUtils.log('✅ تم تهيئة جميع ميزات الخريطة بنجاح', tag: 'AdminMap');
  }

  @override
  void dispose() {
    _disposeMapFeatures();
    super.dispose();
  }

  void _disposeMapFeatures() {
    disposePickupPoints();
    disposeRoutes();
    disposePassengers();
    disposeDrivers();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;

    final selectedDriverId = _findDriverIdByAnnotation(annotation);
    if (selectedDriverId != null) {
      _showDriverDetailsBottomSheet(selectedDriverId);
      return;
    }

    final selectedPickupId = _findPickupIdByAnnotation(annotation);
    if (selectedPickupId != null) {
      handlePickupTap(selectedPickupId);
      return;
    }

    MapUtils.log(
      '⚠️ تم النقر على علامة غير معروفة: ${annotation.id}',
      tag: 'AdminMap',
    );
  }

  String? _findDriverIdByAnnotation(PointAnnotation annotation) {
    for (final entry in driverAnnotations.entries) {
      if (entry.value.id == annotation.id) {
        return entry.key;
      }
    }
    return null;
  }

  String? _findPickupIdByAnnotation(PointAnnotation annotation) {
    for (final entry in pickupAnnotations.entries) {
      if (entry.value.id == annotation.id) {
        return entry.key;
      }
    }
    return null;
  }

  void _showDriverDetailsBottomSheet(String driverId) {
    if (!mounted) return;
    MapUtils.showSnackBar(
      context,
      '🔄 جاري تحميل بيانات السائق (ID: $driverId)...',
      duration: const Duration(seconds: 2),
    );
  }

  void _startAddPickupPoint() {
    if (_isAddingPickupPoint) return;
    setState(() => _isAddingPickupPoint = true);
    MapUtils.showSnackBar(
      context,
      '📍 اضغط على الخريطة لتحديد موقع النقطة',
      duration: const Duration(seconds: 3),
    );
  }

  void _cancelAddPickupPoint() {
    if (!_isAddingPickupPoint) return;
    setState(() => _isAddingPickupPoint = false);
    MapUtils.showSnackBar(
      context,
      '❌ تم إلغاء إضافة النقطة',
      isError: true,
      duration: const Duration(seconds: 1),
    );
  }

  void _handleMapTap(Point point) async {
    if (!_isAddingPickupPoint) return;
    if (!mounted) return;

    print("==== MAP TAP RECEIVED ====");

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    final userData = authProvider.userData;

    if (userId == null || userData == null) {
      MapUtils.showSnackBar(
        context,
        '⚠️ يرجى تسجيل الدخول أولاً',
        isError: true,
      );
      if (mounted) setState(() => _isAddingPickupPoint = false);
      return;
    }

    final double lat = point.coordinates.lat.toDouble();
    final double lng = point.coordinates.lng.toDouble();

    final name = await PickupPointDialog.show(context: context);
    if (!mounted) return;

    if (name == null || name.trim().isEmpty) {
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    try {
      await _pickupManager.addPickupPoint(
        name: name.trim(),
        latitude: lat,
        longitude: lng,
        userId: userId,
        userType: userData.userType,
      );

      if (!mounted) return;

      MapUtils.showSnackBar(
        context,
        '✅ تم إضافة النقطة "${name.trim()}" بنجاح',
      );
    } catch (e) {
      if (!mounted) return;
      MapUtils.log('❌ فشل إضافة النقطة: $e', tag: 'AdminMap');
      MapUtils.showSnackBar(
        context,
        '❌ حدث خطأ أثناء إضافة النقطة. يرجى المحاولة لاحقاً.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isAddingPickupPoint = false);
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
            if (!_isAddingPickupPoint) return;
            _handleMapTap(event.point);
          },
          styleUri: currentMapStyle,
        ),
        if (!isMapReady) const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 30,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'admin_passengers_toggle',
            onPressed: togglePassengersVisibility,
            backgroundColor:
                showPassengers ? Colors.blue.shade700 : Colors.grey,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: Icon(
              showPassengers ? Icons.person : Icons.person_off,
              size: 26,
            ),
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
            elevation: 4,
            shape: const CircleBorder(),
            child: Icon(
              _isAddingPickupPoint ? Icons.close : Icons.add_location,
              size: 26,
            ),
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
