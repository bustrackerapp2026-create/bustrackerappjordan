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
import '../../../services/live_tracking_service.dart';
import 'mixins/driver_location_mixin.dart';

/// خريطة السائق المتقدمة: تتبع حي + تنبؤ موقع + رحلات + نقاط تجمع.
class DriverMapTab extends StatefulWidget {
  const DriverMapTab({super.key});

  @override
  State<DriverMapTab> createState() => _DriverMapTabState();
}

class _DriverMapTabState extends State<DriverMapTab>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        MapCoreMixin<DriverMapTab>,
        PickupPointMixin<DriverMapTab>,
        TripManagerMixin<DriverMapTab>,
        DriverLocationMixin<DriverMapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;
  bool _mapInitialized = false;

  @override
  bool get wantKeepAlive => true;

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
    disposeMapDebug();
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
    await Future.wait([
      initAnnotationManager(),
      applyStableGestures(),
    ]);
    await mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(35.9106, 31.9522)),
        zoom: 12,
        pitch: 0,
        bearing: 0,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await applyLabelLayersFilter();
    listenToPickupPoints();

    // إن كان السائق متصلاً مسبقاً — ابدأ التتبع فوراً
    final driver = context.read<DriverProvider>();
    if (driver.isOnline || driver.isTripActive) {
      await ensureDriverTrackingRunning();
    }

    if (mounted) setState(() => isMapReady = true);
  }

  Future<void> _onToggleOnline() async {
    final driver = context.read<DriverProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) return;

    driver.toggleOnlineStatus();
    final isOnline = driver.isOnline;
    final pos = driver.currentPosition;

    try {
      await LiveTrackingService().setDriverOnlineStatus(
        uid: uid,
        isOnline: isOnline,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        route: _selectedRoute,
      );
      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        isOnline
            ? '🟢 أنت متصل — يظهر موقعك للركاب الآن'
            : '⚪ تم إيقاف المشاركة',
      );
    } catch (e) {
      driver.toggleOnlineStatus();
      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        'تعذر تحديث حالة الاتصال',
        isError: true,
      );
    }

    await refreshDriverTrackingProfile();
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

  Future<void> _onRouteChanged(String route) async {
    setState(() => _selectedRoute = route);
    final driver = context.read<DriverProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null || !driver.isOnline) return;

    final pos = driver.currentPosition;
    try {
      await LiveTrackingService().setDriverOnlineStatus(
        uid: uid,
        isOnline: true,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        route: route,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        RepaintBoundary(
          child: MapWidget(
            key: const ValueKey('driver_map'),
            textureView: true,
            onMapCreated: _onMapCreated,
            onCameraChangeListener: onCameraChangedForDebug,
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

        // شريط البحث
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: RepaintBoundary(
            child: SearchBarWidget(
              selectedRoute: _selectedRoute,
              routes: AppConstants.jordanRoutes,
              onRouteChanged: _onRouteChanged,
              onSearchSubmitted: _searchPlace,
            ),
          ),
        ),

        // شريط حالة سريع أعلى اليمين (سرعة + متابعة)
        Positioned(
          top: 80,
          left: 16,
          child: RepaintBoundary(
            child: Selector<DriverProvider, double?>(
              selector: (_, p) => p.currentPosition?.speed,
              builder: (context, speed, _) {
                final kmh = (speed != null && speed.isFinite && speed > 0)
                    ? (speed * 3.6)
                    : null;
                return _QuickHud(
                  speedKmh: kmh,
                  following: followDriverCamera,
                  tripActive: context.select<DriverProvider, bool>(
                    (p) => p.isTripActive,
                  ),
                );
              },
            ),
          ),
        ),

        // أزرار التحكم
        Positioned(
          bottom: 150,
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
                setState(() {});
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

        // لوحة الحالة السفلية
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
                  routeName: _selectedRoute,
                  isOnline: state.isOnline,
                  isTripActive: state.isTripActive,
                  isProcessingTrip: isProcessingTrip,
                  followingCamera: followDriverCamera,
                  onToggleOnline: _onToggleOnline,
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

/// شريط معلومات سريع (سرعة / حالة الرحلة / متابعة)
class _QuickHud extends StatelessWidget {
  final double? speedKmh;
  final bool following;
  final bool tripActive;

  const _QuickHud({
    required this.speedKmh,
    required this.following,
    required this.tripActive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed,
              size: 18,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              speedKmh != null
                  ? '${speedKmh!.toStringAsFixed(0)} كم/س'
                  : '-- كم/س',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            if (tripActive) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'رحلة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
            if (following) ...[
              const SizedBox(width: 8),
              Icon(Icons.gps_fixed, size: 16, color: Colors.green.shade700),
            ],
          ],
        ),
      ),
    );
  }
}

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
  final String routeName;
  final bool isOnline;
  final bool isTripActive;
  final bool isProcessingTrip;
  final bool followingCamera;
  final VoidCallback onToggleOnline;
  final VoidCallback onTripPressed;

  const _DriverStatusPanel({
    required this.userName,
    required this.routeName,
    required this.isOnline,
    required this.isTripActive,
    required this.isProcessingTrip,
    required this.followingCamera,
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚗 $userName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline
                          ? '🟢 متصل — الخط: $routeName'
                          : '⚪ غير متصل',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isTripActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    followingCamera ? '🔴 رحلة + متابعة' : '🔴 رحلة نشطة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onToggleOnline,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isOnline ? Colors.grey.shade200 : AppTheme.primaryColor,
                    foregroundColor:
                        isOnline ? Colors.black87 : Colors.white,
                  ),
                  child: Text(isOnline ? 'قطع الاتصال' : 'اتصال'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: isProcessingTrip ? null : onTripPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isTripActive ? Colors.red.shade600 : Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isTripActive ? 'إنهاء الرحلة' : 'بدء الرحلة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
