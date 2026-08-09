import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../core/trip/trip_manager_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../map/utils/map_helpers.dart';
import '../../../driver/providers/driver_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/location_service.dart';

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
        TripManagerMixin<DriverMapTab> {
  PointAnnotation? _userAnnotation;
  Uint8List? _cachedUserMarkerBytes;
  bool _isLoadingLocation = false;
  String _selectedRoute = AppConstants.jordanRoutes.first;
  StreamSubscription<geo.Position>? _locationSubscription;
  double _currentBearing = 0.0;
  final LocationService _locationService = LocationService();

  @override
  bool get suppressPoiTap => isAddingPickupPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMarkerImage();
  }

  Future<void> _loadMarkerImage() async {
    _cachedUserMarkerBytes = await MapUtils.preloadMarkerImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    disposePickupPoints();
    disposeTripManager();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLoadingLocation) {
      _goToMyLocation();
    }
    if (state == AppLifecycleState.detached) {
      _locationSubscription?.cancel();
    }
  }

  Future<void> _updateUserMarker(double lat, double lng, double bearing) async {
    if (pointAnnotationManager == null) return;
    final point = Point(coordinates: Position(lng, lat));
    if (_userAnnotation != null) {
      _userAnnotation!.geometry = point;
      _userAnnotation!.iconRotate = bearing;
      await pointAnnotationManager?.update(_userAnnotation!);
      return;
    }
    _cachedUserMarkerBytes ??= await MapHelpers.createUserMarkerBytes();
    if (_cachedUserMarkerBytes == null) return;
    _userAnnotation = await pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: point,
        image: _cachedUserMarkerBytes!,
        iconSize: 1.0,
        iconAnchor: IconAnchor.CENTER,
        iconRotate: bearing,
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      if (!await _locationService.checkAndRequestPermission()) {
        if (!mounted) return;
        MapUtils.showSnackBar(context, '⚠️ يرجى تفعيل خدمة الموقع.',
            isError: true);
        return;
      }
      if (!mounted) return;

      _locationSubscription?.cancel();
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;

      if (position == null) {
        MapUtils.showSnackBar(context, '⚠️ تعذر الحصول على الموقع.',
            isError: true);
        return;
      }

      double bearing = position.heading;
      if (bearing == 0.0 && position.speed > 0) bearing = _currentBearing;
      setState(() => _currentBearing = bearing);

      await flyToFlat(
        latitude: position.latitude,
        longitude: position.longitude,
        zoom: 16,
      );
      await _updateUserMarker(position.latitude, position.longitude, bearing);

      if (!mounted) return;
      context.read<DriverProvider>().updatePosition(position);

      _locationSubscription = _locationService
          .getPositionStream(distanceFilter: 5)
          .listen((pos) {
        if (!mounted) return;
        double newBearing = pos.heading;
        if (newBearing == 0.0 && pos.speed > 0) newBearing = _currentBearing;
        setState(() => _currentBearing = newBearing);
        mapboxMap?.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(pos.longitude, pos.latitude)),
            zoom: 16,
            pitch: 0,
            bearing: 0,
          ),
        );
        _updateUserMarker(pos.latitude, pos.longitude, newBearing);
        context.read<DriverProvider>().updatePosition(pos);
      });

      if (!mounted) return;
      MapUtils.showSnackBar(context, '📍 تم تحديد موقعك.');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _recenterCamera() {
    final pos = context.read<DriverProvider>().currentPosition;
    if (pos == null) {
      MapUtils.showSnackBar(context, '⚠️ لا يوجد موقع محدد.', isError: true);
      return;
    }
    flyToFlat(
      latitude: pos.latitude,
      longitude: pos.longitude,
      zoom: 16.5,
    );
  }

  Future<void> _searchPlace(String query) async {
    if (!mounted) return;
    await MapUtils.searchPlace(
      context,
      mapboxMap,
      query,
      0,
      _locationService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('driver_map'),
          onMapCreated: (map) async {
            mapboxMap = map;
            await initAnnotationManager();
            await applyGoogleLikeCameraBehavior();
            mapboxMap?.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(35.9106, 31.9522)),
                zoom: 12,
                pitch: 0,
                bearing: 0,
              ),
            );
            applyMapConstraints();
            await Future<void>.delayed(const Duration(milliseconds: 400));
            await applyLabelLayersFilter();
            listenToPickupPoints();
          },
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
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SearchBarWidget(
            selectedRoute: _selectedRoute,
            routes: AppConstants.jordanRoutes,
            onRouteChanged: (r) => setState(() => _selectedRoute = r),
            onSearchSubmitted: _searchPlace,
          ),
        ),
        Positioned(
          bottom: 140,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'driver_compass',
                onPressed: resetNorth,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.textColor,
                child: const Icon(Icons.explore_outlined),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'driver_recenter',
                onPressed: _recenterCamera,
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                child: const Icon(Icons.center_focus_strong),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'driver_my_location',
                onPressed: _goToMyLocation,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                child: _isLoadingLocation
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
                onPressed: () => showMapSettingsSheet(context),
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.textColor,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.layers, size: 26),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'driver_add_pickup',
                onPressed: () {
                  toggleAddingPickupPoint();
                  MapUtils.showSnackBar(
                    context,
                    isAddingPickupPoint
                        ? '📍 اضغط على الخريطة لإضافة نقطة'
                        : '❌ تم الإلغاء',
                    isError: !isAddingPickupPoint,
                  );
                },
                backgroundColor:
                    isAddingPickupPoint ? Colors.red : Colors.orange,
                foregroundColor: Colors.white,
                child: Icon(
                  isAddingPickupPoint ? Icons.close : Icons.add_location,
                ),
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
              final user = context.watch<AuthProvider>().userData;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🚗 مرحباً ${user?.fullName ?? "السائق"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(state.isOnline ? 'متاح' : 'غير متاح'),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context
                                .read<DriverProvider>()
                                .toggleOnlineStatus(),
                            child: Text(state.isOnline ? 'متصل' : 'توصيل'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isProcessingTrip
                                ? null
                                : (state.isTripActive ? endTrip : startTrip),
                            child: Text(
                              state.isTripActive ? 'إنهاء' : 'بدء الرحلة',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
