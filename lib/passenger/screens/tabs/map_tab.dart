import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../l10n/app_localizations.dart';
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

  @override
  bool get wantKeepAlive => true;

  @override
  bool get suppressPoiTap => isAddingPickupPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    preloadPassengerMarker();
  }

  @override
  void dispose() {
    disposeMapDebug();
    WidgetsBinding.instance.removeObserver(this);
    disposeLiveTracking();
    disposePassengerLocation();
    disposePickupPoints();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onPassengerLocationLifecycle(state);
    if (state == AppLifecycleState.resumed) {
      startLiveDriverTracking(routeFilter: _selectedRoute);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
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
    final pickupId = findPickupIdByAnnotation(annotation);
    if (pickupId != null) {
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
    listenToPickupPoints();
    startLiveDriverTracking(routeFilter: _selectedRoute);
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
                  onPressed: () => showMapSettingsSheet(context),
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textColor,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.layers, size: 26),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'passenger_my_location',
                  onPressed: goToMyLocation,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                radius: 18,
                child: const Icon(
                  Icons.directions_bus,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.liveTracking,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    liveCount > 0
                        ? l10n.liveBusesCount(liveCount)
                        : l10n.noLiveBuses,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              routeName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
