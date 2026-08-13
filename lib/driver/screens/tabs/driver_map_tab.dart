import 'dart:async';

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
import '../../../l10n/app_localizations.dart';
import 'mixins/driver_location_mixin.dart';
import 'mixins/route_plan_recording_mixin.dart';

/// خريطة السائق: تتبع حي + رحلات + تسجيل مسار خطة الخط — كل العمليات مربوطة بـ uid السائق الحالي فقط.
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
        DriverLocationMixin<DriverMapTab>,
        RoutePlanRecordingMixin<DriverMapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;
  bool _mapInitialized = false;
  bool _showMap = false;

  /// يعيد بناء الشاشة دورياً لإظهار/إخفاء تنبيه الموقع القديم
  Timer? _staleCheckTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  bool get suppressPoiTap => isAddingPickupPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showMap = true);
      });
    });
    preloadDriverMarker();

    // فحص كل 30 ثانية: هل الموقع قديم بينما السائق متصل؟
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final driver = context.read<DriverProvider>();
      if (driver.isOnline || isRecordingRoutePlan) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _staleCheckTimer?.cancel();
    _staleCheckTimer = null;
    disposeMapDebug();
    WidgetsBinding.instance.removeObserver(this);
    disposeRoutePlanRecording();
    disposeDriverLocation();
    disposePickupPoints();
    disposeTripManager();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onDriverLocationLifecycle(state);
    // عند العودة للتطبيق أعد فحص القِدم فوراً
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void onStyleChanged() {
    listenToPickupPoints();
    unawaited(initRoutePlanLayer());
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;
    final pickupId = findPickupIdByAnnotation(annotation);
    if (pickupId != null) {
      MapUtils.lightHaptic();
      showPickupPointSheet(pickupId);
    }
  }

  Future<void> _searchPlace(String query) async {
    if (!mounted) return;
    final map = mapboxMap;
    final loc = locationService;
    await MapUtils.searchPlace(
      context,
      map,
      query,
      0,
      loc,
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    if (_mapInitialized) return;
    _mapInitialized = true;

    try {
      mapboxMap = map;
      await Future.wait([
        initAnnotationManager(),
        applyStableGestures(),
      ]);
      if (!mounted) return;

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
      if (!mounted) return;

      listenToPickupPoints();
      await initRoutePlanLayer();

      final driver = context.read<DriverProvider>();
      final auth = context.read<AuthProvider>();
      final uid = auth.userId;
      if (uid != null && uid.isNotEmpty) {
        listenDriverPlannedRoutes(uid);
      }

      if (driver.isBound &&
          driver.boundUserId == auth.userId &&
          (driver.isOnline || driver.isTripActive)) {
        await ensureDriverTrackingRunning();
      }

      if (mounted) setState(() => isMapReady = true);
    } catch (e, st) {
      debugPrint('DriverMapTab _onMapCreated error: $e\n$st');
      if (mounted) {
        setState(() => isMapReady = true);
      }
    }
  }

  Future<void> _onToggleOnline() async {
    if (!mounted) return;
    final driver = context.read<DriverProvider>();
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context);
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) return;

    if (!driver.isBound || driver.boundUserId != uid) {
      driver.bindToUser(uid);
    }

    MapUtils.mediumHaptic();
    final ok = driver.toggleOnlineStatus(userId: uid);
    if (!ok) return;

    final isOnline = driver.isOnline;
    final pos = driver.currentPosition;
    final route = _selectedRoute;

    try {
      await LiveTrackingService().setDriverOnlineStatus(
        uid: uid,
        isOnline: isOnline,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        route: route,
        isTripActive: driver.isTripActive,
      );
      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        isOnline ? l10n.driverOnlineMsg : l10n.driverOfflineMsg,
      );
    } catch (e) {
      if (mounted) driver.toggleOnlineStatus(userId: uid);
      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        l10n.onlineStatusFailed,
        isError: true,
      );
    }

    if (mounted) await refreshDriverTrackingProfile();
  }

  Future<void> _onTripButtonPressed({required bool isTripActive}) async {
    if (isProcessingTrip) return;
    final auth = context.read<AuthProvider>();
    final driver = context.read<DriverProvider>();
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) return;
    if (!driver.isBound || driver.boundUserId != uid) {
      driver.bindToUser(uid);
    }

    MapUtils.mediumHaptic();

    if (isTripActive) {
      await endTrip();
      if (!mounted) return;
      try {
        await LiveTrackingService().setDriverTripActive(
          uid: uid,
          isTripActive: false,
        );
      } catch (_) {}
      if (!mounted) return;
      if (isAddingPickupPoint) {
        toggleAddingPickupPoint();
      }
      setState(() => followDriverCamera = false);
    } else {
      await startTrip();
      if (!mounted) return;
      try {
        await LiveTrackingService().setDriverTripActive(
          uid: uid,
          isTripActive: true,
        );
      } catch (_) {}
      if (!mounted) return;
      if (isAddingPickupPoint) {
        toggleAddingPickupPoint();
      }
      setState(() => followDriverCamera = true);
    }

    if (mounted) await refreshDriverTrackingProfile();
  }

  Future<void> _onRouteChanged(String route) async {
    if (!mounted) return;
    setState(() => _selectedRoute = route);
    MapUtils.lightHaptic();

    final driver = context.read<DriverProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null || !driver.isOnline || driver.boundUserId != uid) return;

    final pos = driver.currentPosition;
    try {
      await LiveTrackingService().setDriverOnlineStatus(
        uid: uid,
        isOnline: true,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        route: route,
        isTripActive: driver.isTripActive,
      );
    } catch (_) {}
  }

  void _openRoutePlanSheet() {
    MapUtils.mediumHaptic();
    showRoutePlanSheet(_selectedRoute);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final isTripActive = context.select<DriverProvider, bool>(
      (p) => p.isTripActive,
    );
    final showStaleBanner = context.select<DriverProvider, bool>(
      (p) => p.isLocationStaleWhileOnline,
    );
    final locationAge = context.select<DriverProvider, String>(
      (p) => p.locationAgeLabel,
    );

    // موضع اللوحات العلوية يعتمد على وجود تنبيهات
    double topOffset = 80;
    if (showStaleBanner) topOffset = 168;
    if (isRecordingRoutePlan) topOffset += 56;

    return Stack(
      children: [
        if (_showMap)
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
          )
        else
          const ColoredBox(
            color: Color(0xFFF0F2F5),
            child: Center(child: CircularProgressIndicator()),
          ),
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
        // تنبيه الموقع القديم أثناء الاتصال
        if (showStaleBanner)
          Positioned(
            top: 78,
            left: 16,
            right: 16,
            child: RepaintBoundary(
              child: _StaleLocationBanner(
                ageLabel: locationAge,
                isRefreshing: isLoadingDriverLocation,
                onRefresh: () {
                  MapUtils.mediumHaptic();
                  goToMyLocation();
                },
                onGoOffline: () {
                  final online = context.read<DriverProvider>().isOnline;
                  if (online) _onToggleOnline();
                },
              ),
            ),
          ),
        // شريط تسجيل مسار الخطة الحي
        if (isRecordingRoutePlan)
          Positioned(
            top: showStaleBanner ? 158 : 78,
            left: 16,
            right: 16,
            child: RepaintBoundary(
              child: _RoutePlanRecordingBanner(
                directionLabel: recordingDirection?.labelAr ?? '',
                pointCount: routePlanPointCount,
                isSaving: isSavingRoutePlan,
                onSave: () => saveRoutePlanRecording(lineName: _selectedRoute),
                onCancel: cancelRoutePlanRecording,
                onOpenSheet: _openRoutePlanSheet,
              ),
            ),
          ),
        Positioned(
          top: topOffset,
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
                  tripActive: isTripActive,
                  l10n: l10n,
                );
              },
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          right: 16,
          child: RepaintBoundary(
            child: _DriverMapFabColumn(
              simplified: isTripActive && !isRecordingRoutePlan,
              followDriverCamera: followDriverCamera,
              isLoadingLocation: isLoadingDriverLocation,
              isAddingPickup: isAddingPickupPoint,
              isRecordingRoutePlan: isRecordingRoutePlan,
              onCompass: () {
                MapUtils.lightHaptic();
                resetNorth();
              },
              onFollow: () {
                MapUtils.lightHaptic();
                toggleFollowDriverCamera();
                if (!mounted) return;
                MapUtils.showSnackBar(
                  context,
                  followDriverCamera
                      ? l10n.followCameraOn
                      : l10n.followCameraOff,
                );
              },
              onRecenter: () {
                MapUtils.lightHaptic();
                recenterDriverCamera();
              },
              onMyLocation: () {
                MapUtils.lightHaptic();
                goToMyLocation();
              },
              onLayers: () {
                if (!mounted) return;
                MapUtils.lightHaptic();
                showMapSettingsSheet(context);
              },
              onAddPickup: () {
                if (isTripActive) return;
                MapUtils.lightHaptic();
                toggleAddingPickupPoint();
                setState(() {});
                if (!mounted) return;
                MapUtils.showSnackBar(
                  context,
                  isAddingPickupPoint
                      ? l10n.tapMapToAddPoint
                      : l10n.cancelled,
                  isError: !isAddingPickupPoint,
                );
              },
              onRoutePlan: _openRoutePlanSheet,
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
                  (a) => a.userData?.fullName ?? l10n.driver,
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
                  l10n: l10n,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// شريط تنبيه أثناء تسجيل مسار الخطة
class _RoutePlanRecordingBanner extends StatelessWidget {
  final String directionLabel;
  final int pointCount;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onOpenSheet;

  const _RoutePlanRecordingBanner({
    required this.directionLabel,
    required this.pointCount,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFFF5F3FF),
      child: InkWell(
        onTap: onOpenSheet,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF7C3AED),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تسجيل $directionLabel · $pointCount نقطة',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ),
              TextButton(
                onPressed: isSaving ? null : onSave,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  isSaving ? '…' : 'حفظ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: isSaving ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط تنبيه: متصل لكن الموقع قديم أو غير متوفر.
class _StaleLocationBanner extends StatelessWidget {
  final String ageLabel;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onGoOffline;

  const _StaleLocationBanner({
    required this.ageLabel,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onGoOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFFFFF7ED),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  size: 18,
                  color: Color(0xFFEA580C),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'موقعك قديم بينما أنت متصل',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'آخر تحديث: $ageLabel — الركاب قد يرون موقعاً غير دقيق.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: isRefreshing ? null : onRefresh,
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: Text(
                        isRefreshing ? 'جاري التحديث…' : 'تحديث موقعي',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: onGoOffline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9A3412),
                        side: const BorderSide(color: Color(0xFFFDBA74)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'قطع الاتصال',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickHud extends StatelessWidget {
  final double? speedKmh;
  final bool following;
  final bool tripActive;
  final AppLocalizations l10n;

  const _QuickHud({
    required this.speedKmh,
    required this.following,
    required this.tripActive,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white.withValues(alpha: 0.97),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.speed_rounded,
                size: 16,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              speedKmh != null
                  ? l10n.speedKmh(speedKmh!.toStringAsFixed(0))
                  : l10n.speedPlaceholder,
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
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(
                  l10n.tripLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
  final bool simplified;
  final bool followDriverCamera;
  final bool isLoadingLocation;
  final bool isAddingPickup;
  final bool isRecordingRoutePlan;
  final VoidCallback onCompass;
  final VoidCallback onFollow;
  final VoidCallback onRecenter;
  final VoidCallback onMyLocation;
  final VoidCallback onLayers;
  final VoidCallback onAddPickup;
  final VoidCallback onRoutePlan;

  const _DriverMapFabColumn({
    required this.simplified,
    required this.followDriverCamera,
    required this.isLoadingLocation,
    required this.isAddingPickup,
    required this.isRecordingRoutePlan,
    required this.onCompass,
    required this.onFollow,
    required this.onRecenter,
    required this.onMyLocation,
    required this.onLayers,
    required this.onAddPickup,
    required this.onRoutePlan,
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
        // زر مسار خطة الخط — متاح دائماً (حتى أثناء الرحلة)
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'driver_route_plan',
          onPressed: onRoutePlan,
          backgroundColor: isRecordingRoutePlan
              ? const Color(0xFF7C3AED)
              : const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          child: Icon(
            isRecordingRoutePlan
                ? Icons.fiber_manual_record
                : Icons.route_rounded,
          ),
        ),
        if (!simplified) ...[
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
  final AppLocalizations l10n;

  const _DriverStatusPanel({
    required this.userName,
    required this.routeName,
    required this.isOnline,
    required this.isTripActive,
    required this.isProcessingTrip,
    required this.followingCamera,
    required this.onToggleOnline,
    required this.onTripPressed,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isTripActive
        ? const Color(0xFFDC2626)
        : (isOnline ? const Color(0xFF16A34A) : const Color(0xFF6B7280));
    final statusText = isTripActive
        ? (followingCamera ? l10n.tripWithFollow : l10n.activeTrip)
        : (isOnline ? l10n.onlineWithRoute(routeName) : l10n.offlineStatus);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOnline
              ? statusColor.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isTripActive
                      ? Icons.route_rounded
                      : (isOnline
                          ? Icons.wifi_tethering_rounded
                          : Icons.wifi_tethering_off_rounded),
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onToggleOnline,
                    icon: Icon(
                      isOnline ? Icons.power_settings_new : Icons.wifi_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isOnline ? l10n.goOffline : l10n.goOnline,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: isOnline
                          ? Colors.grey.shade100
                          : AppTheme.primaryColor,
                      foregroundColor:
                          isOnline ? Colors.black87 : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isProcessingTrip ? null : onTripPressed,
                    icon: isProcessingTrip
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isTripActive
                                ? Icons.stop_circle_outlined
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                    label: Text(
                      isTripActive ? l10n.endTrip : l10n.startTrip,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: isTripActive
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
