import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../core/trip/trip_manager_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../driver/providers/driver_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'mixins/driver_location_mixin.dart';

/// خريطة السائق — أداء محسّن (عزل الرسم + أقل setState)
class DriverMapTab extends StatefulWidget {
  const DriverMapTab({super.key});

  @override
  State<DriverMapTab> createState() => _DriverMapTabState();
}

class _DriverMapTabState extends State<DriverMapTab>
    with
        WidgetsBindingObserver,
        MapCoreMixin<DriverMapTab>,
        PickupPointMixin<DriverMapTab>,
        TripManagerMixin<DriverMapTab>,
        DriverLocationMixin<DriverMapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;
  bool _mapInitialized = false;

  @override
  bool get suppressPoiTap => isAddingPickupPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    preloadDriverMarker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeDriverLocation();
    disposePickupPoints();
    disposeTripManager();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onDriverLocationLifecycle(state);
  }

  @override
  void onStyleChanged() {
    listenToPickupPoints();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;
    final pickupId = findPickupIdByAnnotation(annotation);
    if (pickupId != null) {
      showPickupPointSheet(pickupId);
    }
  }

  Future<void> _searchPlace(String query) async {
    if (!mounted) return;
    await MapUtils.searchPlace(
      context,
      mapboxMap,
      query,
      0,
      locationService,
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    if (_mapInitialized) return;
    _mapInitialized = true;

    mapboxMap = map;
    await initAnnotationManager();
    await applyGoogleLikeCameraBehavior();
    await mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(35.9106, 31.9522)),
        zoom: 12,
        pitch: 0,
        bearing: 0,
      ),
    );
    applyMapConstraints();

    // تهيئة الطبقات بدون setState غير ضروري
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await applyLabelLayersFilter();
    listenToPickupPoints();
    // لا setState هنا — isMapReady غير مستخدم في build
    isMapReady = true;
  }

  Future<void> _onTripButtonPressed({required bool isTripActive}) async {
    if (isProcessingTrip) return;

    if (isTripActive) {
      await endTrip();
      if (!mounted) return;
      setState(() => followDriverCamera = false);
    } else {
      await startTrip();
      if (!mounted) return;
      setState(() => followDriverCamera = true);
    }

    await refreshDriverTrackingProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // الخريطة معزولة عن إعادة رسم الأزرار
        RepaintBoundary(
          child: MapWidget(
            key: const ValueKey('driver_map'),
            onMapCreated: _onMapCreated,
            styleUri: currentMapStyle,
            // ignore: deprecated_member_use
            onTapListener: (event) {
              if (isAddingPickupPoint) {
                handleAddPickupPoint(event.point);
              } else {
                handleMapBackgroundTap(event);
              }
            },
          ),
        ),

        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: RepaintBoundary(
            child: SearchBarWidget(
              selectedRoute: _selectedRoute,
              routes: AppConstants.jordanRoutes,
              onRouteChanged: (r) => setState(() => _selectedRoute = r),
              onSearchSubmitted: _searchPlace,
            ),
          ),
        ),

        Positioned(
          bottom: 140,
          right: 16,
          child: RepaintBoundary(
            child: _DriverMapFabColumn(
              followDriverCamera: followDriverCamera,
              isLoadingLocation: isLoadingDriverLocation,
              isAddingPickup: isAddingPickupPoint,
              onCompass: resetNorth,
              onFollow: () {
                toggleFollowDriverCamera();
                MapUtils.showSnackBar(
                  context,
                  followDriverCamera
                      ? '📡 متابعة الكاميرا مفعّلة'
                      : '✋ متابعة الكاميرا متوقفة',
                );
              },
              onRecenter: recenterDriverCamera,
              onMyLocation: goToMyLocation,
              onLayers: () => showMapSettingsSheet(context),
              onAddPickup: () {
                toggleAddingPickupPoint();
                MapUtils.showSnackBar(
                  context,
                  isAddingPickupPoint
                      ? '📍 اضغط على الخريطة لإضافة نقطة'
                      : '❌ تم الإلغاء',
                  isError: !isAddingPickupPoint,
                );
              },
            ),
          ),
        ),

        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: RepaintBoundary(
            child: Selector<
                DriverProvider, ({bool isOnline, bool isTripActive})>(
              selector: (_, p) =>
                  (isOnline: p.isOnline, isTripActive: p.isTripActive),
              shouldRebuild: (prev, next) =>
                  prev.isOnline != next.isOnline ||
                  prev.isTripActive != next.isTripActive,
              builder: (context, state, _) {
                final userName = context.select<AuthProvider, String>(
                  (a) => a.userData?.fullName ?? 'السائق',
                );
                return _DriverStatusPanel(
                  userName: userName,
                  isOnline: state.isOnline,
                  isTripActive: state.isTripActive,
                  isProcessingTrip: isProcessingTrip,
                  onToggleOnline: () =>
                      context.read<DriverProvider>().toggleOnlineStatus(),
                  onTripPressed: () => _onTripButtonPressed(
                    isTripActive: state.isTripActive,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// أزرار الخريطة كودجت مستقل لتقليل بناء الشجرة
class _DriverMapFabColumn extends StatelessWidget {
  final bool followDriverCamera;
  final bool isLoadingLocation;
  final bool isAddingPickup;
  final VoidCallback onCompass;
  final VoidCallback onFollow;
  final VoidCallback onRecenter;
  final VoidCallback onMyLocation;
  final VoidCallback onLayers;
  final VoidCallback onAddPickup;

  const _DriverMapFabColumn({
    required this.followDriverCamera,
    required this.isLoadingLocation,
    required this.isAddingPickup,
    required this.onCompass,
    required this.onFollow,
    required this.onRecenter,
    required this.onMyLocation,
    required this.onLayers,
    required this.onAddPickup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'driver_compass',
          onPressed: onCompass,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textColor,
          child: const Icon(Icons.explore_outlined),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.small(
          heroTag: 'driver_follow',
          onPressed: onFollow,
          backgroundColor:
              followDriverCamera ? AppTheme.primaryColor : Colors.white,
          foregroundColor:
              followDriverCamera ? Colors.white : AppTheme.textColor,
          child: Icon(
            followDriverCamera ? Icons.gps_fixed : Icons.gps_not_fixed,
          ),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'driver_recenter',
          onPressed: onRecenter,
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          child: const Icon(Icons.center_focus_strong),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'driver_my_location',
          onPressed: onMyLocation,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          child: isLoadingLocation
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'driver_map_layers',
          onPressed: onLayers,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textColor,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.layers, size: 26),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'driver_add_pickup',
          onPressed: onAddPickup,
          backgroundColor: isAddingPickup ? Colors.red : Colors.orange,
          foregroundColor: Colors.white,
          child: Icon(isAddingPickup ? Icons.close : Icons.add_location),
        ),
      ],
    );
  }
}

class _DriverStatusPanel extends StatelessWidget {
  final String userName;
  final bool isOnline;
  final bool isTripActive;
  final bool isProcessingTrip;
  final VoidCallback onToggleOnline;
  final VoidCallback onTripPressed;

  const _DriverStatusPanel({
    required this.userName,
    required this.isOnline,
    required this.isTripActive,
    required this.isProcessingTrip,
    required this.onToggleOnline,
    required this.onTripPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🚗 مرحباً $userName',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(isOnline ? 'متاح' : 'غير متاح'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onToggleOnline,
                  child: Text(isOnline ? 'متصل' : 'توصيل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: isProcessingTrip ? null : onTripPressed,
                  child: Text(isTripActive ? 'إنهاء' : 'بدء الرحلة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
