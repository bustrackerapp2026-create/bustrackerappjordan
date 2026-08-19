import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_landmarks_display_mixin.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../core/trip/trip_manager_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../driver/providers/driver_provider.dart';
import '../../../driver/widgets/driver_active_trip_banner.dart';
import '../../../driver/widgets/driver_pending_request_banner.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/trip_model.dart';
import '../../../models/trip_status.dart';
import '../../../services/live_tracking_service.dart';
import '../../../services/map_camera_prefs_service.dart';
import '../../../services/trip_service.dart';
import '../../../services/trip_service_exception.dart';
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

  final TripService _tripService = TripService();
  StreamSubscription<List<TripModel>>? _pendingSub;
  StreamSubscription<List<TripModel>>? _activeSub;

  TripModel? _pendingTrip;
  TripModel? _activeBoardTrip;
  bool _handlingRequest = false;
  bool _completingBoard = false;
  String? _dismissedTripId;

  /// آخر طلب تم تنبيه السائق عليه (اهتزاز + تركيز كاميرا).
  String? _lastAlertedPendingId;

  PointAnnotation? _pickupAnnotation;
  Uint8List? _pickupPinBytes;
  String? _pickupMarkerTripId;

  @override
  bool get wantKeepAlive => true;

  @override
  String get mapCameraPrefsRole => MapCameraPrefsService.roleDriver;

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
      _watchPendingRequests();
      _watchActiveBoardTrips();
    });
    preloadDriverMarker();
    unawaited(_ensurePickupPinImage());
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !widget.isActive) return;
      final driver = context.read<DriverProvider>();
      if (driver.isOnline || isRecordingRoutePlan) setState(() {});
    });
  }

  Future<void> _ensurePickupPinImage() async {
    if (_pickupPinBytes != null) return;
    try {
      _pickupPinBytes = await _buildPickupPinPng();
    } catch (e) {
      debugPrint('pickup pin image: $e');
    }
  }

  static Future<Uint8List> _buildPickupPinPng() async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fill = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    // دائرة علوية
    canvas.drawCircle(const Offset(size / 2, 34), 22, fill);
    canvas.drawCircle(const Offset(size / 2, 34), 22, stroke);

    // نقطة داخلية
    canvas.drawCircle(
      const Offset(size / 2, 34),
      8,
      Paint()..color = Colors.white,
    );

    // مثلث سفلي (دبوس)
    final path = Path()
      ..moveTo(size / 2 - 16, 48)
      ..lineTo(size / 2 + 16, 48)
      ..lineTo(size / 2, size - 10)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke..strokeWidth = 3);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  /// تنبيه مرة واحدة لكل طلب جديد: اهتزاز + توجيه الكاميرا لموقع الراكب.
  void _alertNewPendingIfNeeded(TripModel? next) {
    if (next == null) return;
    // لا نكرر التنبيه لنفس الطلب
    if (next.id == _lastAlertedPendingId) return;
    // إذا كان هناك رحلة نشطة فالبانر أصلاً لا يظهر
    if (_activeBoardTrip != null) return;
    if (!widget.isActive) return;

    _lastAlertedPendingId = next.id;
    unawaited(MapUtils.alertHaptic());

    if (next.pickupLat != null && next.pickupLng != null) {
      unawaited(flyToFlat(
        latitude: next.pickupLat!,
        longitude: next.pickupLng!,
        zoom: 16,
      ));
    }
  }

  void _watchPendingRequests() {
    _pendingSub?.cancel();
    final uid = context.read<AuthProvider>().userId;
    if (uid == null || uid.isEmpty) return;

    _pendingSub = _tripService.getPendingDriverTrips(uid).listen(
      (list) {
        if (!mounted) return;
        TripModel? next;
        if (list.isNotEmpty) {
          for (final t in list) {
            if (t.id != _dismissedTripId) {
              next = t;
              break;
            }
          }
          next ??= list.first;
          if (next.id == _dismissedTripId && list.length == 1) {
            next = null;
          }
        } else {
          _dismissedTripId = null;
          _lastAlertedPendingId = null;
        }
        setState(() => _pendingTrip = next);
        _alertNewPendingIfNeeded(next);
      },
      onError: (e, st) {
        debugPrint('driver pending trips: $e\n$st');
      },
    );
  }

  void _watchActiveBoardTrips() {
    _activeSub?.cancel();
    final uid = context.read<AuthProvider>().userId;
    if (uid == null || uid.isEmpty) return;

    _activeSub = _tripService.getActiveDriverTrips(uid).listen(
      (list) {
        if (!mounted) return;
        // فضّل رحلة راكب حقيقية (فيها passengerId) على رحلة يدوية فارغة
        TripModel? board;
        for (final t in list) {
          if (t.passengerId.trim().isNotEmpty) {
            board = t;
            break;
          }
        }
        board ??= list.isEmpty ? null : list.first;
        setState(() => _activeBoardTrip = board);
        unawaited(_syncPickupMarker(board));
      },
      onError: (e, st) {
        debugPrint('driver active trips: $e\n$st');
      },
    );
  }

  Future<void> _syncPickupMarker(TripModel? trip) async {
    if (!mounted || pointAnnotationManager == null) return;

    final lat = trip?.pickupLat;
    final lng = trip?.pickupLng;
    final hasCoords = trip != null && lat != null && lng != null;

    if (!hasCoords) {
      await _clearPickupMarker();
      return;
    }

    // نفس الرحلة ونفس الموضع → لا إعادة إنشاء
    if (_pickupAnnotation != null &&
        _pickupMarkerTripId == trip.id &&
        trip.pickupLat == lat &&
        trip.pickupLng == lng) {
      return;
    }

    await _clearPickupMarker();
    if (!mounted || pointAnnotationManager == null) return;

    await _ensurePickupPinImage();
    if (!mounted) return;

    try {
      final options = PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        iconSize: 0.85,
        iconAnchor: IconAnchor.BOTTOM,
        textField: trip.passengerName?.trim().isNotEmpty == true
            ? trip.passengerName!.trim()
            : 'نقطة صعود',
        textSize: 12.0,
        textOffset: [0.0, 1.15],
        textColor: const Color(0xFF9A3412).toARGB32(),
        textHaloColor: Colors.white.toARGB32(),
        textHaloWidth: 1.4,
        image: _pickupPinBytes,
      );
      final ann = await pointAnnotationManager!.create(options);
      if (!mounted) return;
      _pickupAnnotation = ann;
      _pickupMarkerTripId = trip.id;
    } catch (e) {
      debugPrint('create pickup marker: $e');
    }
  }

  Future<void> _clearPickupMarker() async {
    final ann = _pickupAnnotation;
    _pickupAnnotation = null;
    _pickupMarkerTripId = null;
    if (ann == null) return;
    try {
      await pointAnnotationManager?.delete(ann);
    } catch (_) {}
  }

  Future<void> _acceptPending() async {
    final trip = _pendingTrip;
    final uid = context.read<AuthProvider>().userId;
    if (trip == null || uid == null || _handlingRequest) return;

    setState(() => _handlingRequest = true);
    try {
      await _tripService.acceptTripTransaction(trip.id, uid);
      if (!mounted) return;

      MapUtils.mediumHaptic();
      MapUtils.showSnackBar(
        context,
        'تم قبول طلب ${_passengerLabel(trip)}',
      );

      // حدّث محلياً فوراً قبل وصول الـ stream
      final accepted = trip.copyWith(status: TripStatus.active);
      setState(() {
        _pendingTrip = null;
        _dismissedTripId = null;
        _activeBoardTrip = accepted;
      });
      await _syncPickupMarker(accepted);

      if (trip.pickupLat != null && trip.pickupLng != null) {
        await flyToFlat(
          latitude: trip.pickupLat!,
          longitude: trip.pickupLng!,
          zoom: 16,
        );
      }
    } catch (e) {
      debugPrint('accept on map: $e');
      if (!mounted) return;
      final msg =
          e is TripServiceException ? e.message : 'تعذر قبول الطلب';
      MapUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _handlingRequest = false);
    }
  }

  Future<void> _rejectPending() async {
    final trip = _pendingTrip;
    final uid = context.read<AuthProvider>().userId;
    if (trip == null || uid == null || _handlingRequest) return;

    setState(() => _handlingRequest = true);
    try {
      await _tripService.updateTripStatus(
        trip.id,
        TripStatus.cancelled,
        driverId: uid,
      );
      if (!mounted) return;
      MapUtils.showSnackBar(context, 'تم رفض الطلب');
      setState(() {
        _pendingTrip = null;
        _dismissedTripId = null;
      });
    } catch (e) {
      debugPrint('reject on map: $e');
      if (!mounted) return;
      final msg =
          e is TripServiceException ? e.message : 'تعذر رفض الطلب';
      MapUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _handlingRequest = false);
    }
  }

  Future<void> _focusPickup(TripModel? trip) async {
    if (trip?.pickupLat == null || trip?.pickupLng == null) return;
    MapUtils.lightHaptic();
    await flyToFlat(
      latitude: trip!.pickupLat!,
      longitude: trip.pickupLng!,
      zoom: 16,
    );
  }

  Future<void> _completeBoardTrip() async {
    final trip = _activeBoardTrip;
    final uid = context.read<AuthProvider>().userId;
    if (trip == null || uid == null || _completingBoard) return;

    setState(() => _completingBoard = true);
    try {
      await _tripService.updateTripStatus(
        trip.id,
        TripStatus.completed,
        driverId: uid,
      );
      if (!mounted) return;
      MapUtils.showSnackBar(context, 'تم تأكيد صعود الراكب');
      setState(() => _activeBoardTrip = null);
      await _clearPickupMarker();
    } catch (e) {
      debugPrint('complete board: $e');
      if (!mounted) return;
      final msg =
          e is TripServiceException ? e.message : 'تعذر إكمال الطلب';
      MapUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _completingBoard = false);
    }
  }

  void _dismissBanner() {
    final id = _pendingTrip?.id;
    setState(() {
      _dismissedTripId = id;
      _pendingTrip = null;
    });
  }

  String _passengerLabel(TripModel trip) {
    final name = trip.passengerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'الراكب';
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
      _watchPendingRequests();
      _watchActiveBoardTrips();
      unawaited(_syncPickupMarker(_activeBoardTrip));
    }
  }

  void _onCameraChanged(CameraChangedEventData data) {
    onCameraChangedForDebug(data);
    onCameraChangedForDisplayLandmarks();
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _activeSub?.cancel();
    _staleCheckTimer?.cancel();
    unawaited(_clearPickupMarker());
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
      _watchPendingRequests();
      _watchActiveBoardTrips();
      unawaited(_syncPickupMarker(_activeBoardTrip));
      setState(() {});
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(persistCurrentCamera());
    }
  }

  @override
  void onStyleChanged() {
    listenToPickupPoints();
    unawaited(initRoutePlanLayer());
    unawaited(redrawDisplayLandmarks());
    // بعد إعادة إنشاء مديري العلامات
    _pickupAnnotation = null;
    _pickupMarkerTripId = null;
    unawaited(_syncPickupMarker(_activeBoardTrip));
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;

    if (_pickupAnnotation != null && annotation.id == _pickupAnnotation!.id) {
      MapUtils.lightHaptic();
      unawaited(_focusPickup(_activeBoardTrip));
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
      await restoreInitialCamera(fallbackZoom: MapConstants.cityZoom);
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
      await _syncPickupMarker(_activeBoardTrip);
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

    final showRequestBanner =
        _pendingTrip != null && widget.isActive && _activeBoardTrip == null;
    final showActiveBanner = _activeBoardTrip != null && widget.isActive;

    double topBannerOffset = 78;
    if (showStaleBanner) topBannerOffset = 140;

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
        if (showRequestBanner)
          Positioned(
            top: topBannerOffset,
            left: 16,
            right: 16,
            child: DriverPendingRequestBanner(
              trip: _pendingTrip!,
              busy: _handlingRequest,
              onAccept: _acceptPending,
              onReject: _rejectPending,
              onFocusPickup: () => _focusPickup(_pendingTrip),
              onDismiss: _dismissBanner,
            ),
          ),
        if (showActiveBanner)
          Positioned(
            top: topBannerOffset,
            left: 16,
            right: 16,
            child: DriverActiveTripBanner(
              trip: _activeBoardTrip!,
              busy: _completingBoard,
              onFocusPickup: () => _focusPickup(_activeBoardTrip),
              onComplete: _completeBoardTrip,
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
