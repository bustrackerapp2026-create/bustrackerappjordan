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
  // ─── متغيرات خاصة بالسائق ──────────────────────────────────────────
  PointAnnotation? _userAnnotation;
  Uint8List? _cachedUserMarkerBytes;

  bool _isLoadingLocation = false;
  String _selectedRoute = AppConstants.jordanRoutes.first;
  StreamSubscription<geo.Position>? _locationSubscription;
  double _currentBearing = 0.0;

  final LocationService _locationService = LocationService();

  // ─── دورة الحياة ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMarkerImage();
    MapUtils.log('📍 DriverMapTab initState', tag: 'DriverMap');
  }

  Future<void> _loadMarkerImage() async {
    _cachedUserMarkerBytes = await MapUtils.preloadMarkerImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _userAnnotation = null;
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

  // ─── تحديث ماركر المستخدم ───────────────────────────────────────────
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

    final options = PointAnnotationOptions(
      geometry: point,
      image: _cachedUserMarkerBytes!,
      iconSize: 1.0,
      iconAnchor: IconAnchor.CENTER,
      iconRotate: bearing,
    );
    _userAnnotation = await pointAnnotationManager?.create(options);
  }

  // ─── تحديد الموقع والتتبع المستمر ──────────────────────────────────
  Future<void> _goToMyLocation() async {
    if (mapboxMap == null) return;
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);

    try {
      final hasPermission = await _locationService.checkAndRequestPermission();
      if (!mounted) return;
      if (!hasPermission) {
        MapUtils.showSnackBar(
            context, '⚠️ يرجى تفعيل خدمة الموقع وإعطاء الصلاحية.',
            isError: true);
        return;
      }

      _locationSubscription?.cancel();

      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        MapUtils.showSnackBar(context, '⚠️ تعذر الحصول على الموقع الحالي.',
            isError: true);
        return;
      }

      MapUtils.log(
          '📍 تم جلب الموقع: ${position.latitude}, ${position.longitude}',
          tag: 'DriverMap');

      double bearing = position.heading;
      if (bearing == 0.0 && position.speed > 0) bearing = _currentBearing;
      if (mounted) setState(() => _currentBearing = bearing);

      mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
              coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
          bearing: bearing,
          pitch: 45.0,
        ),
      );
      await _updateUserMarker(position.latitude, position.longitude, bearing);

      if (mounted) {
        context.read<DriverProvider>().updatePosition(position);
      }

      _locationSubscription = _locationService
          .getPositionStream(distanceFilter: 5)
          .listen((geo.Position pos) {
        if (mounted) {
          double newBearing = pos.heading;
          if (newBearing == 0.0 && pos.speed > 0) newBearing = _currentBearing;
          setState(() => _currentBearing = newBearing);

          mapboxMap?.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(pos.longitude, pos.latitude)),
              zoom: 15.0,
              bearing: newBearing,
              pitch: 45.0,
            ),
          );
          _updateUserMarker(pos.latitude, pos.longitude, newBearing);
          context.read<DriverProvider>().updatePosition(pos);
        }
      }, onError: (error) {
        MapUtils.log('⚠️ خطأ في تحديث الموقع: $error', tag: 'DriverMap');
      });

      MapUtils.showSnackBar(context, '📍 تم تحديد موقعك.', isError: false);
    } catch (e) {
      if (!mounted) return;
      MapUtils.log('❌ خطأ في تحديد الموقع: $e', tag: 'DriverMap');
      MapUtils.showSnackBar(context, '❌ تعذر تحديد موقعك.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // ─── إعادة تمركز الكاميرا ───────────────────────────────────────────
  void _recenterCamera() {
    final driverProvider = context.read<DriverProvider>();
    final pos = driverProvider.currentPosition;
    if (pos == null) {
      MapUtils.showSnackBar(context, '⚠️ لا يوجد موقع محدد حالياً.',
          isError: true);
      return;
    }
    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 16.0,
        bearing: _currentBearing,
        pitch: 45.0,
      ),
    );
    MapUtils.showSnackBar(context, '🔄 تم إعادة التمركز.', isError: false);
  }

  // ─── البحث عن مكان ───────────────────────────────────────────────────
  Future<void> _searchPlace(String query) async {
    await MapUtils.searchPlace(
        context, mapboxMap, query, _currentBearing, _locationService);
  }

  // ─── واجهة المستخدم ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('driver_map'),
          onMapCreated: (map) {
            mapboxMap = map;
            initAnnotationManager();
            mapboxMap?.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(35.9106, 31.9522)),
                zoom: 12.0,
              ),
            );
            applyLabelLayersFilter();
            applyMapConstraints();
            listenToPickupPoints();
            MapUtils.log('✅ تم تهيئة خريطة السائق', tag: 'DriverMap');
          },
          styleUri: currentMapStyle,
          // ignore: deprecated_member_use
          onTapListener: (event) {
            if (isAddingPickupPoint) {
              handleAddPickupPoint(event.point);
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
            onRouteChanged: (newRoute) {
              setState(() => _selectedRoute = newRoute);
              MapUtils.showSnackBar(context, '🔄 تم تصفية الخط: $newRoute',
                  isError: false);
            },
            onSearchSubmitted: (query) async => _searchPlace(query),
          ),
        ),
        Positioned(
          bottom: 140,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'driver_recenter',
                onPressed: _recenterCamera,
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.center_focus_strong, size: 24),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'driver_my_location',
                onPressed: _goToMyLocation,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                elevation: 4,
                shape: const CircleBorder(),
                child: _isLoadingLocation
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
                        ? '📍 اضغط على الخريطة لإضافة نقطة جديدة'
                        : '❌ تم إلغاء إضافة النقطة',
                    isError: !isAddingPickupPoint,
                  );
                },
                backgroundColor:
                    isAddingPickupPoint ? Colors.red : Colors.orange,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: Icon(
                  isAddingPickupPoint ? Icons.close : Icons.add_location,
                  size: 26,
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
            selector: (_, provider) => (
              isOnline: provider.isOnline,
              isTripActive: provider.isTripActive,
            ),
            builder: (context, state, _) {
              return Consumer<AuthProvider>(
                builder: (context, authProvider, __) {
                  final user = authProvider.userData;
                  final isOnline = state.isOnline;
                  final isTripActive = state.isTripActive;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🚗 مرحباً ${user?.fullName ?? "السائق"}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.circle,
                                        size: 10,
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.red),
                                    const SizedBox(width: 4),
                                    Text(isOnline ? 'متاح' : 'غير متاح',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isOnline
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 12),
                                    Text(
                                        '🧭 ${_currentBearing.toStringAsFixed(1)}°',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(_selectedRoute,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context
                                      .read<DriverProvider>()
                                      .toggleOnlineStatus();
                                  MapUtils.showSnackBar(
                                    context,
                                    isOnline
                                        ? '🟢 أصبحت متاحاً للطلبات'
                                        : '🔴 تم إيقاف الاستقبال',
                                    isError: false,
                                  );
                                },
                                icon: Icon(
                                    isOnline ? Icons.wifi : Icons.wifi_off,
                                    size: 18),
                                label: Text(isOnline ? 'متصل' : 'توصيل'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isOnline ? Colors.green : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isProcessingTrip
                                    ? null
                                    : (isTripActive ? endTrip : startTrip),
                                icon: isProcessingTrip
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Icon(
                                        isTripActive
                                            ? Icons.stop
                                            : Icons.play_arrow,
                                        size: 18),
                                label: Text(isProcessingTrip
                                    ? 'جاري...'
                                    : (isTripActive ? 'إنهاء' : 'بدء الرحلة')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isTripActive
                                      ? Colors.red
                                      : AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
