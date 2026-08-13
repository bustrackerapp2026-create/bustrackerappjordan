import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/analytics_service.dart';
import 'mixins/passenger_location_mixin.dart';
import 'mixins/passenger_live_tracking_mixin.dart';

/// خريطة الراكب مع تتبع حي للباصات المتصلة.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        MapCoreMixin<MapTab>,
        PickupPointMixin<MapTab>,
        PassengerLocationMixin<MapTab>,
        PassengerLiveTrackingMixin<MapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;
  bool _mapInitialized = false;
  bool _loggedMapOpened = false;
  bool _loggedEmptyState = false;
  int? _lastLiveCount;

  @override
  bool get wantKeepAlive => true;

  @override
  bool get suppressPoiTap => isAddingPickupPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    preloadPassengerMarker();
    liveDriversCount.addListener(_onLiveCountChanged);
  }

  void _onLiveCountChanged() {
    if (_liveTrackingDisposedLike) return;
    final count = liveDriversCount.value;
    if (_lastLiveCount == count) return;
    _lastLiveCount = count;

    if (count == 0) {
      if (!_loggedEmptyState) {
        _loggedEmptyState = true;
        AnalyticsService().noLiveBusesViewed(route: _selectedRoute);
      }
    } else {
      _loggedEmptyState = false;
      AnalyticsService().liveBusesViewed(count, route: _selectedRoute);
    }
  }

  /// حماية بسيطة إن تم dispose الـ notifier
  bool get _liveTrackingDisposedLike {
    try {
      // ignore: unnecessary_statements
      liveDriversCount.value;
      return false;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    try {
      liveDriversCount.removeListener(_onLiveCountChanged);
    } catch (_) {}
    disposeLiveTracking();
    disposeMapDebug();
    WidgetsBinding.instance.removeObserver(this);
    disposePassengerLocation();
    disposePickupPoints();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onPassengerLocationLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        startLiveDriverTracking(routeFilter: _selectedRoute);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      stopLiveDriverTracking();
    }
  }

  @override
  void onStyleChanged() {
    listenToPickupPoints();
    startLiveDriverTracking(routeFilter: _selectedRoute);
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;

    final driverId = findDriverIdByAnnotation(annotation);
    if (driverId != null) {
      MapUtils.lightHaptic();
      final data = getLiveDriverData(driverId);
      AnalyticsService().driverMarkerTapped(
        capacity: data?.capacity?.toString(),
      );
      showDriverInfoSheet(driverId);
      return;
    }

    final pickupId = findPickupIdByAnnotation(annotation);
    if (pickupId != null) {
      MapUtils.lightHaptic();
      AnalyticsService().pickupMarkerTapped();
      showPickupPointSheet(pickupId);
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    if (_mapInitialized) return;
    _mapInitialized = true;

    mapboxMap = map;
    await Future.wait([
      initAnnotationManager(),
      applyStableGestures(),
    ]);
    if (!mounted) return;

    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(35.9106, 31.9522)),
        zoom: 12.0,
        pitch: 0,
        bearing: 0,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await applyLabelLayersFilter();
    if (!mounted) return;
    listenToPickupPoints();
    startLiveDriverTracking(routeFilter: _selectedRoute);

    if (!_loggedMapOpened) {
      _loggedMapOpened = true;
      AnalyticsService().passengerMapOpened();
    }

    if (mounted) setState(() => isMapReady = true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        RepaintBoundary(
          child: MapWidget(
            key: const ValueKey('passenger_map'),
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
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: RepaintBoundary(
            child: SearchBarWidget(
              selectedRoute: _selectedRoute,
              routes: AppConstants.jordanRoutes,
              onRouteChanged: (newRoute) {
                setState(() => _selectedRoute = newRoute);
                updateLiveTrackingRouteFilter(newRoute);
                _loggedEmptyState = false;
                MapUtils.lightHaptic();
                AnalyticsService().routeFilterChanged(newRoute);
                MapUtils.showSnackBar(
                  context,
                  l10n.routeFiltered(newRoute),
                );
              },
              onSearchSubmitted: searchPassengerPlace,
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          right: 16,
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'passenger_map_layers',
                  onPressed: () {
                    MapUtils.lightHaptic();
                    showMapSettingsSheet(context);
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textColor,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.layers, size: 26),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'passenger_my_location',
                  onPressed: () {
                    MapUtils.lightHaptic();
                    goToMyLocation();
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: isLoadingPassengerLocation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 28),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'passenger_add_pickup',
                  onPressed: () {
                    MapUtils.lightHaptic();
                    toggleAddingPickupPoint();
                    MapUtils.showSnackBar(
                      context,
                      isAddingPickupPoint
                          ? l10n.tapMapAddNewPoint
                          : l10n.cancelAddPoint,
                      isError: !isAddingPickupPoint,
                    );
                    setState(() {});
                  },
                  backgroundColor:
                      isAddingPickupPoint ? Colors.red : Colors.white,
                  foregroundColor: isAddingPickupPoint
                      ? Colors.white
                      : AppTheme.primaryColor,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: Icon(
                    isAddingPickupPoint
                        ? Icons.close
                        : Icons.add_location_alt_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 16,
          right: 16,
          child: RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: liveDriversCount,
              builder: (context, count, _) {
                return _LiveStatusBar(
                  routeName: _selectedRoute,
                  liveCount: count,
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

class _LiveStatusBar extends StatelessWidget {
  final String routeName;
  final int liveCount;
  final AppLocalizations l10n;

  const _LiveStatusBar({
    required this.routeName,
    required this.liveCount,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final hasLive = liveCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasLive
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (hasLive)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      ),
                    ),
                  CircleAvatar(
                    backgroundColor: hasLive
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : Colors.grey.shade100,
                    radius: 18,
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: hasLive ? AppTheme.primaryColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                  if (hasLive)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.liveTracking,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLive
                          ? l10n.liveBusesCount(liveCount)
                          : l10n.noLiveBuses,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasLive
                            ? const Color(0xFF16A34A)
                            : Colors.grey.shade600,
                        fontWeight:
                            hasLive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  routeName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (!hasLive) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'جرّب تغيير الخط من القائمة أعلاه، أو انتظر قليلاً حتى يتصل سائق على هذا المسار.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
