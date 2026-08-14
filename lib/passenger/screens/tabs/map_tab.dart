import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/nearest_stop_finder.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../core/trip/eta_utils.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/live_driver_location.dart';
import '../../../models/planned_route.dart';
import '../../../models/trip_model.dart';
import '../../../passenger/widgets/active_trip_banner.dart';
import '../../../passenger/widgets/passenger_live_status_bar.dart';
import '../../../passenger/widgets/passenger_map_fabs.dart';
import '../../../services/analytics_service.dart';
import '../../../services/route_prefs_service.dart';
import '../../../services/route_plan_service.dart';
import '../../../services/trip_service.dart';
import 'mixins/passenger_location_mixin.dart';
import 'mixins/passenger_live_tracking_mixin.dart';
import 'mixins/passenger_planned_routes_mixin.dart';

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
        PassengerLiveTrackingMixin<MapTab>,
        PassengerPlannedRoutesMixin<MapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;
  bool _mapInitialized = false;
  bool _loggedMapOpened = false;
  bool _loggedEmptyState = false;
  int? _lastLiveCount;
  bool _findingNearest = false;

  final TripService _tripService = TripService();
  StreamSubscription<List<TripModel>>? _openTripsSub;
  TripModel? _openTrip;

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
    _loadPreferredRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchOpenTrips());
  }

  void _watchOpenTrips() {
    _openTripsSub?.cancel();
    final uid = context.read<AuthProvider>().userId;
    if (uid == null || uid.isEmpty) return;
    _openTripsSub = _tripService.watchPassengerOpenTrips(uid).listen((list) {
      if (!mounted) return;
      setState(() => _openTrip = list.isEmpty ? null : list.first);
    }, onError: (e) {
      debugPrint('open trips watch: $e');
    });
  }

  Future<void> _loadPreferredRoute() async {
    final route = await RoutePrefsService().loadPreferredRoute();
    if (!mounted) return;
    if (route != _selectedRoute) {
      setState(() => _selectedRoute = route);
      updateLiveTrackingRouteFilter(route);
      updatePlannedRoutesLineFilter(route);
    }
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

  bool get _liveTrackingDisposedLike {
    try {
      liveDriversCount.value;
      return false;
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    _openTripsSub?.cancel();
    try {
      liveDriversCount.removeListener(_onLiveCountChanged);
    } catch (_) {}
    disposePlannedRoutes();
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
        startWatchingPlannedRoutes(_selectedRoute);
        _watchOpenTrips();
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
    unawaited(redrawPlannedRoutes());
  }

  Future<void> _openDriverSheet(String driverId) async {
    await showDriverInfoSheet(
      driverId,
      passengerLat: lastPassengerLat,
      passengerLng: lastPassengerLng,
      onRequestBoard: _requestBoard,
    );
  }

  Future<void> _requestBoard(LiveDriverLocation driver) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      MapUtils.showSnackBar(context, 'سجّل الدخول أولاً لطلب الصعود',
          isError: true);
      throw StateError('not logged in');
    }

    if (!hasPassengerLocation) {
      await goToMyLocation();
      if (!mounted) return;
      if (!hasPassengerLocation) {
        MapUtils.showSnackBar(
          context,
          'حدّد موقعك أولاً لطلب الصعود',
          isError: true,
        );
        throw StateError('no location');
      }
    }

    final lat = lastPassengerLat!;
    final lng = lastPassengerLng!;

    final nearest = await NearestStopFinder.findNearestApproved(
      lat: lat,
      lng: lng,
    );
    if (!mounted) return;

    final String pickupName;
    final double pickupLat;
    final double pickupLng;

    if (nearest != null) {
      pickupName = nearest.stop.name;
      pickupLat = nearest.stop.latitude;
      pickupLng = nearest.stop.longitude;
      unawaited(flyToFlat(
        latitude: pickupLat,
        longitude: pickupLng,
        zoom: 16,
      ));
    } else {
      pickupName = 'موقعي الحالي';
      pickupLat = lat;
      pickupLng = lng;
    }

    try {
      await _tripService.createBoardRequest(
        passengerId: uid,
        driverId: driver.driverId,
        pickupPoint: pickupName,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        route: driver.route ?? _selectedRoute,
        passengerName: auth.userData?.fullName,
        driverName: driver.fullName,
        busNumber: driver.busNumber,
        dropoffPoint: 'على طول الخط',
      );

      if (!mounted) return;
      final where = nearest != null
          ? 'محطة «$pickupName» (${EtaUtils.formatDistance(nearest.meters)})'
          : 'موقعك الحالي';
      MapUtils.showSnackBar(
        context,
        'تم إرسال طلب الصعود إلى ${driver.fullName} من $where',
      );
      _watchOpenTrips();
    } catch (e) {
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          'فشل إرسال الطلب. تحقق من الصلاحيات أو الاتصال.',
          isError: true,
        );
      }
      rethrow;
    }
  }

  Future<void> _cancelOpenTrip() async {
    final trip = _openTrip;
    final uid = context.read<AuthProvider>().userId;
    if (trip == null || uid == null) return;

    try {
      await _tripService.cancelTripByPassenger(
        tripId: trip.id,
        passengerId: uid,
      );
      if (!mounted) return;
      setState(() => _openTrip = null);
      MapUtils.showSnackBar(context, 'تم إلغاء الطلب');
    } catch (e, st) {
      debugPrint('cancel trip failed: $e\n$st');
      if (!mounted) return;
      final msg = e.toString();
      final friendly = msg.contains('permission-denied') ||
              msg.contains('PERMISSION_DENIED')
          ? 'صلاحيات الإلغاء غير مفعّلة. انشر firestore.rules ثم أعد المحاولة.'
          : msg.contains('غير موجودة')
              ? 'الطلب غير موجود أو أُلغي مسبقاً'
              : 'تعذر إلغاء الطلب';
      MapUtils.showSnackBar(context, friendly, isError: true);
    }
  }

  Future<void> _focusOpenTripDriver() async {
    final trip = _openTrip;
    if (trip == null || trip.driverId.isEmpty) return;
    final data = getLiveDriverData(trip.driverId);
    if (data != null && data.hasValidCoords) {
      await flyToFlat(
        latitude: data.latitude,
        longitude: data.longitude,
        zoom: 15.5,
      );
      return;
    }
    if (!mounted) return;
    MapUtils.showSnackBar(context, 'جاري تحديد موقع السائق...');
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
      unawaited(_openDriverSheet(driverId));
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
      initPolylineManager(),
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
    startWatchingPlannedRoutes(_selectedRoute);

    if (!_loggedMapOpened) {
      _loggedMapOpened = true;
      AnalyticsService().passengerMapOpened();
    }

    if (mounted) setState(() => isMapReady = true);
  }

  Future<void> _onRouteChanged(String newRoute) async {
    setState(() => _selectedRoute = newRoute);
    updateLiveTrackingRouteFilter(newRoute);
    updatePlannedRoutesLineFilter(newRoute);
    _loggedEmptyState = false;
    MapUtils.lightHaptic();
    AnalyticsService().routeFilterChanged(newRoute);
    await RoutePrefsService().savePreferredRoute(newRoute);
    if (!mounted) return;
    MapUtils.showSnackBar(
      context,
      AppLocalizations.of(context).routeFiltered(newRoute),
    );
  }

  Future<void> _onSearchSubmitted(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    for (final name in AppConstants.jordanRoutes) {
      if (ArabicSearch.matches(query: q, lineName: name)) {
        await _onRouteChanged(name);
        return;
      }
    }

    try {
      final found = await RoutePlanService().searchApprovedRoutes(q);
      if (!mounted) return;
      if (found.isNotEmpty) {
        final line = found.first.lineName;
        if (!AppConstants.jordanRoutes.contains(line)) {
          setState(() => _selectedRoute = line);
          updateLiveTrackingRouteFilter(line);
          updatePlannedRoutesLineFilter(line);
          await RoutePrefsService().savePreferredRoute(line);
        } else {
          await _onRouteChanged(line);
        }
        if (!mounted) return;
        final dirs = found.map((r) => r.direction.labelAr).toSet().join(' و');
        MapUtils.showSnackBar(
          context,
          '🚌 $line ($dirs) — ${found.length} مسار معتمد',
        );
        return;
      }
    } catch (e) {
      debugPrint('passenger route search: $e');
    }

    await searchPassengerPlace(q);
  }

  Future<void> _findNearestBus() async {
    if (_findingNearest) return;
    MapUtils.mediumHaptic();

    if (!hasPassengerLocation) {
      MapUtils.showSnackBar(
        context,
        'حدّد موقعك أولاً بزر موقعي',
        isError: true,
      );
      await goToMyLocation();
      if (!hasPassengerLocation) return;
    }

    setState(() => _findingNearest = true);
    try {
      final result = findNearestDriver(
        lastPassengerLat!,
        lastPassengerLng!,
      );
      if (!mounted) return;

      if (result == null) {
        MapUtils.showSnackBar(
          context,
          'لا يوجد باص حي على هذا الخط حالياً',
          isError: true,
        );
        return;
      }

      final meters = result.meters;
      final km = meters / 1000.0;
      final distanceLabel = meters < 1000
          ? '${meters.toStringAsFixed(0)} م'
          : '${km.toStringAsFixed(1)} كم';

      await flyToFlat(
        latitude: result.driver.latitude,
        longitude: result.driver.longitude,
        zoom: 15.5,
      );

      if (!mounted) return;
      MapUtils.showSnackBar(
        context,
        'أقرب باص: ${result.driver.fullName} · $distanceLabel',
      );
      await _openDriverSheet(result.driver.driverId);
    } finally {
      if (mounted) setState(() => _findingNearest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final hasOpenTrip = _openTrip != null;

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
              onRouteChanged: _onRouteChanged,
              onSearchSubmitted: _onSearchSubmitted,
            ),
          ),
        ),
        Positioned(
          bottom: hasOpenTrip ? 200 : 120,
          right: 16,
          child: RepaintBoundary(
            child: PassengerMapFabs(
              findingNearest: _findingNearest,
              isLoadingPassengerLocation: isLoadingPassengerLocation,
              isAddingPickupPoint: isAddingPickupPoint,
              onNearestBus: _findingNearest ? null : _findNearestBus,
              onMapLayers: () {
                MapUtils.lightHaptic();
                showMapSettingsSheet(context);
              },
              onMyLocation: () {
                MapUtils.lightHaptic();
                goToMyLocation();
              },
              onTogglePickup: () {
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
            ),
          ),
        ),
        if (hasOpenTrip)
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: ActiveTripBanner(
              trip: _openTrip!,
              onCancel: _cancelOpenTrip,
              onFocusDriver: _focusOpenTripDriver,
            ),
          )
        else
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: liveDriversCount,
                builder: (context, count, _) {
                  return PassengerLiveStatusBar(
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
