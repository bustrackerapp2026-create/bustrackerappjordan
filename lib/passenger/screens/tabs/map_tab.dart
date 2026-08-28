import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_landmarks_display_mixin.dart';
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
import '../../../passenger/widgets/destination_search_sheet.dart';
import '../../../passenger/widgets/passenger_live_status_bar.dart';
import '../../../passenger/widgets/passenger_map_fabs.dart';
import '../../../services/analytics_service.dart';
import '../../../services/location_service.dart';
import '../../../services/map_camera_prefs_service.dart';
import '../../../services/nearby_routes_service.dart';
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
        MapCoreMixin,
        PickupPointMixin,
        PassengerLocationMixin,
        PassengerLiveTrackingMixin,
        PassengerPlannedRoutesMixin,
        MapLandmarksDisplayMixin {
  final TripService _tripService = TripService();
  final RoutePrefsService _routePrefs = RoutePrefsService();
  final NearbyRoutesService _nearbyRoutes = NearbyRoutesService();

  String _selectedRoute = AppConstants.defaultRoute;
  PlaceSearchResult? _destination;
  TripModel? _openTrip;
  StreamSubscription? _tripsSub;
  bool _mapInitialized = false;
  bool _loggedMapOpened = false;
  bool _findingNearby = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initRoutePrefs());
  }

  Future<void> _initRoutePrefs() async {
    final saved = await _routePrefs.getSelectedRoute();
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _selectedRoute = saved);
    }
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    disposeLiveTracking();
    disposePassengerLocation();
    disposePlannedRoutes();
    disposeDisplayLandmarks();
    super.dispose();
  }

  Future<void> _openDriverSheet(String driverId) async {
    await showDriverInfoSheet(
      driverId,
      passengerLat: lastPassengerLat,
      passengerLng: lastPassengerLng,
      onRequestBoard: _requestBoard,
      onFollowBus: _followBus,
    );
  }

  void _followBus(LiveDriverLocation driver) {
    if (!driver.hasValidCoords) return;
    unawaited(flyToFlat(
      latitude: driver.latitude,
      longitude: driver.longitude,
      zoom: 16.0,
    ));
    if (mounted) {
      final bus = driver.busNumber?.trim();
      final label =
          (bus != null && bus.isNotEmpty) ? 'باص $bus' : driver.displayLabel;
      MapUtils.showSnackBar(context, 'جاري متابعة $label');
    }
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
      AnalyticsService().pickupMarkerTapped();
      showPickupPointSheet(pickupId);
    }
  }

  Future<void> _requestBoard(LiveDriverLocation driver) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) {
      MapUtils.showSnackBar(context, 'سجّل الدخول أولاً لطلب الصعود');
      throw StateError('not logged in');
    }

    final lat = lastPassengerLat;
    final lng = lastPassengerLng;
    if (lat == null || lng == null) {
      MapUtils.showSnackBar(context, 'فعّل الموقع أولاً');
      throw StateError('no location');
    }

    final nearest = NearestStopFinder.find(
      lat: lat,
      lng: lng,
      points: approvedPickupPoints,
    );

    String pickupName;
    double pickupLat;
    double pickupLng;
    String pickupDetail;

    if (nearest != null) {
      pickupName = nearest.point.name;
      pickupLat = nearest.point.latitude;
      pickupLng = nearest.point.longitude;
      pickupDetail =
          'محطة معتمدة · ${EtaUtils.formatDistance(nearest.meters)}';
      unawaited(flyToFlat(
        latitude: pickupLat,
        longitude: pickupLng,
        zoom: 16,
      ));
    } else {
      pickupName = 'موقعي الحالي';
      pickupLat = lat;
      pickupLng = lng;
      pickupDetail = 'لا توجد محطة معتمدة قريبة — يُستخدم موقعك';
    }

    final dropoff = _destination?.name.trim().isNotEmpty == true
        ? _destination!.name.trim()
        : 'على طول الخط';

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
        dropoffPoint: dropoff,
      );

      if (!mounted) return;
      final where = nearest != null
          ? 'محطة «$pickupName» (${EtaUtils.formatDistance(nearest.meters)})'
          : 'موقعك الحالي';
      MapUtils.showSnackBar(
        context,
        'تم إرسال طلب الصعود إلى ${driver.fullName} من $where',
      );
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

  Future<void> _showBusesNearMe({bool silent = false}) async {
    final lat = lastPassengerLat;
    final lng = lastPassengerLng;
    if (lat == null || lng == null) {
      if (!silent) {
        MapUtils.showSnackBar(context, 'فعّل الموقع أولاً');
      }
      return;
    }
    setState(() => _findingNearby = true);
    try {
      final result = findNearestDriver(lat, lng);
      if (result == null) {
        if (!silent && mounted) {
          MapUtils.showSnackBar(context, 'لا يوجد باص قريب حالياً');
        }
        return;
      }
      if (!mounted) return;
      await flyToFlat(
        latitude: result.driver.latitude,
        longitude: result.driver.longitude,
        zoom: 15.5,
      );
      await _openDriverSheet(result.driver.driverId);
    } finally {
      if (mounted) setState(() => _findingNearby = false);
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

    await restoreInitialCamera(fallbackZoom: MapConstants.cityZoom);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await applyLabelLayersFilter();
    if (!mounted) return;
    listenToPickupPoints();
    startLiveDriverTracking(routeFilter: _selectedRoute);
    startWatchingPlannedRoutes(_selectedRoute);
    listenToDisplayLandmarks();

    if (!_loggedMapOpened) {
      _loggedMapOpened = true;
      AnalyticsService().passengerMapOpened();
    }

    if (mounted) setState(() => isMapReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: MapConstants.styleUri,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  MapConstants.defaultLng,
                  MapConstants.defaultLat,
                ),
              ),
              zoom: MapConstants.cityZoom,
            ),
            onTapListener: (event) {},
          ),
          if (isMapReady)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  if (_openTrip != null)
                    ActiveTripBanner(
                      trip: _openTrip!,
                      onCancel: () {},
                      onFocusDriver: () {},
                    ),
                  PassengerLiveStatusBar(
                    selectedRoute: _selectedRoute,
                    destinationName: _destination?.name,
                    liveDriversCount: liveDriversCount,
                    onClearDestination: () =>
                        setState(() => _destination = null),
                  ),
                ],
              ),
            ),
          if (isMapReady)
            Positioned(
              bottom: 24,
              right: 16,
              child: PassengerMapFabs(
                onMyLocation: () => unawaited(goToPassengerLocation()),
                onNearbyBuses: _findingNearby ? null : () => _showBusesNearMe(),
                findingNearby: _findingNearby,
              ),
            ),
        ],
      ),
    );
  }
}
