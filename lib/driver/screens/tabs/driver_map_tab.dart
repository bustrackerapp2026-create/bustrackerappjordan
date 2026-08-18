import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_landmarks_display_mixin.dart';
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

/// خريطة السائق.
class DriverMapTab extends StatefulWidget {
  final bool isActive;
  const DriverMapTab({super.key, this.isActive = true});

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
        RoutePlanRecordingMixin<DriverMapTab>,
        MapLandmarksDisplayMixin<DriverMapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;
  bool _mapInitialized = false;
  bool _showMap = false;
  Timer? _staleCheckTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  bool get isMapTabActive => widget.isActive;

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
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !widget.isActive) return;
      final driver = context.read<DriverProvider>();
      if (driver.isOnline || isRecordingRoutePlan) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DriverMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (!widget.isActive) {
      pauseMapUiUpdates();
    } else if (mounted) {
      final driver = context.read<DriverProvider>();
      final auth = context.read<AuthProvider>();
      if (driver.isBound &&
          driver.boundUserId == auth.userId &&
          (driver.isOnline || driver.isTripActive)) {
        unawaited(ensureDriverTrackingRunning());
      }
      listenToDisplayLandmarks();
    }
  }

  void _onCameraChanged(CameraChangedEventData data) {
    onCameraChangedForDebug(data);
    onCameraChangedForDisplayLandmarks();
  }

  @override
  void dispose() {
    _staleCheckTimer?.cancel();
    disposeDisplayLandmarks();
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
    if (state == AppLifecycleState.resumed && mounted) {
      listenToDisplayLandmarks();
      setState(() {});
    }
  }

  @override
  void onStyleChanged() {
    listenToPickupPoints();
    unawaited(initRoutePlanLayer());
    unawaited(redrawDisplayLandmarks());
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;

    final landmarkId = findDisplayLandmarkIdByAnnotation(annotation);
    if (landmarkId != null) {
      final m = getDisplayLandmarkById(landmarkId);
      if (m != null) {
        MapUtils.lightHaptic();
        showDisplayLandmarkInfoSheet(context, m);
      }
      return;
    }

    final pickupId = findPickupIdByAnnotation(annotation);
    if (pickupId != null) {
      MapUtils.lightHaptic();
      showPickupPointSheet(pickupId);
    }
  }

  Future<void> _searchPlace(String query) async {
    if (!mounted) return;
    await MapUtils.searchPlace(context, mapboxMap, query, 0, locationService);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    if (_mapInitialized) return;
    _mapInitialized = true;
    try {
      mapboxMap = map;
      await Future.wait([initAnnotationManager(), applyStableGestures()]);
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
      if (!mounted) return;
      listenToDisplayLandmarks();
      final auth = context.read<AuthProvider>();
      if (auth.userId != null && auth.userId!.isNotEmpty) {
        listenLinePlannedRoutes(_selectedRoute);
      }
      final driver = context.read<DriverProvider>();
      if (driver.isBound &&
          driver.boundUserId == auth.userId &&
          (driver.isOnline || driver.isTripActive)) {
        await ensureDriverTrackingRunning();
      }
      if (mounted) setState(() => isMapReady = true);
    } catch (e, st) {
      debugPrint('DriverMapTab _onMapCreated error: $e\n$st');
      if (mounted) setState(() => isMapReady = true);
    }
  }

  Future<void> _onToggleOnline() async {
    if (!mounted) return;
    final driver = context.read<DriverProvider>();
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context);
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) return;
    if (!driver.isBound || driver.boundUserId != uid) driver.bindToUser(uid);
    MapUtils.mediumHaptic();
    final ok = driver.toggleOnlineStatus(userId: uid);
    if (!ok) return;
    final isOnline = driver.isOnline;
    final pos = driver.currentPosition;
    try {
      await LiveTrackingService().setDriverOnlineStatus(
        uid: uid,
        isOnline: isOnline,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        route: _selectedRoute,
        isTripActive: driver.isTripActive,
      );
      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        isOnline ? l10n.driverOnlineMsg : l10n.driverOfflineMsg,
      );
    } catch (_) {
      if (mounted) driver.toggleOnlineStatus(userId: uid);
      if (!mounted) return;
      MapUtils.showSnackBar(context, l10n.onlineStatusFailed, isError: true);
    }
    if (mounted) await refreshDriverTrackingProfile();
  }

  Future<void> _onTripButtonPressed({required bool isTripActive}) async {
    if (isProcessingTrip) return;
    final auth = context.read<AuthProvider>();
    final driver = context.read<DriverProvider>();
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) return;
    if (!driver.isBound || driver.boundUserId != uid) driver.bindToUser(uid);
    MapUtils.mediumHaptic();
    if (isTripActive) {
      await endTrip();
      if (!mounted) return;
      try {
        await LiveTrackingService()
            .setDriverTripActive(uid: uid, isTripActive: false);
      } catch (_) {}
      if (!mounted) return;
      if (isAddingPickupPoint) toggleAddingPickupPoint();
      setState(() => followDriverCamera = false);
    } else {
      await startTrip();
      if (!mounted) return;
      try {
        await LiveTrackingService()
            .setDriverTripActive(uid: uid, isTripActive: true);
      } catch (_) {}
      if (!mounted) return;
      if (isAddingPickupPoint) toggleAddingPickupPoint();
      setState(() => followDriverCamera = true);
    }
    if (mounted) await refreshDriverTrackingProfile();
  }

  Future<void> _onRouteChanged(String route) async {
    if (!mounted) return;
    setState(() => _selectedRoute = route);
    MapUtils.lightHaptic();
    listenLinePlannedRoutes(route);
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
    final showStaleBanner = context.select<DriverProvider, bool>(
      (p) => p.isLocationStaleWhileOnline,
    );
    final locationAge =
        context.select<DriverProvider, String>((p) => p.locationAgeLabel);

    return Stack(
      children: [
        if (_showMap)
          TickerMode(
            enabled: widget.isActive,
            child: RepaintBoundary(
              child: IgnorePointer(
                ignoring: !widget.isActive,
                child: MapWidget(
                  key: const ValueKey('driver_map'),
                  textureView: true,
                  onMapCreated: _onMapCreated,
                  onCameraChangeListener:
                      widget.isActive ? _onCameraChanged : null,
                  styleUri: currentMapStyle,
                  // ignore: deprecated_member_use
                  onTapListener: (event) {
                    if (!widget.isActive) return;
                    if (isAddingPickupPoint) {
                      handleAddPickupPoint(event.point);
                    } else {
                      handleMapBackgroundTap(event);
                    }
                  },
                ),
              ),
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
          child: SearchBarWidget(
            selectedRoute: _selectedRoute,
            routes: AppConstants.jordanRoutes,
            onRouteChanged: _onRouteChanged,
            onSearchSubmitted: _searchPlace,
          ),
        ),
        if (showStaleBanner)
          Positioned(
            top: 78,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFFF7ED),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'موقعك قديم ($locationAge) — حدّث موقعك أو اقطع الاتصال',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 150,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'driver_compass',
                onPressed: () {
                  MapUtils.lightHaptic();
                  resetNorth();
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.explore_outlined),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'driver_my_location',
                onPressed: () {
                  MapUtils.lightHaptic();
                  goToMyLocation();
                },
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                child: isLoadingDriverLocation
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'driver_route_plan',
                onPressed: _openRoutePlanSheet,
                backgroundColor: const Color(0xFF8B5CF6),
                child: const Icon(Icons.route_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Selector<DriverProvider, ({bool isOnline, bool isTripActive})>(
            selector: (_, p) =>
                (isOnline: p.isOnline, isTripActive: p.isTripActive),
            builder: (context, state, _) {
              final userName = context.select<AuthProvider, String>(
                (a) => a.userData?.fullName ?? l10n.driver,
              );
              return Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.isTripActive
                            ? l10n.activeTrip
                            : (state.isOnline
                                ? l10n.onlineWithRoute(_selectedRoute)
                                : l10n.offlineStatus),
                        style: TextStyle(
                          color: state.isOnline
                              ? Colors.green.shade700
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _onToggleOnline,
                              child: Text(
                                state.isOnline ? l10n.goOffline : l10n.goOnline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isProcessingTrip
                                  ? null
                                  : () => _onTripButtonPressed(
                                        isTripActive: state.isTripActive,
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: state.isTripActive
                                    ? Colors.red
                                    : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                state.isTripActive
                                    ? l10n.endTrip
                                    : l10n.startTrip,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
