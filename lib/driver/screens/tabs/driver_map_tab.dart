import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../map/widgets/map_settings_sheet.dart';
import '../../../map/utils/map_helpers.dart';

// ✅ استخدام الاستيراد المباشر (تأكد من مطابقة المسار لمشروعك)
import '../../../driver/providers/driver_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

class DriverMapTab extends StatefulWidget {
  const DriverMapTab({super.key});

  @override
  State<DriverMapTab> createState() => _DriverMapTabState();
}

class _DriverMapTabState extends State<DriverMapTab>
    with WidgetsBindingObserver {
  // --- متغيرات الخريطة ---
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _userAnnotation;
  Uint8List? _cachedUserMarkerBytes;

  // --- متغيرات الموقع والحالة ---
  bool _isLoadingLocation = false;
  String _selectedRoute = AppConstants.jordanRoutes.first;
  StreamSubscription<geo.Position>? _locationSubscription;
  double _currentBearing = 0.0;

  // --- إعدادات الخريطة ---
  bool _showPlaceLabels = true;
  bool _showPoiLabels = true;
  bool _showRoadLabels = true;
  String _currentMapStyle = MapboxStyles.MAPBOX_STREETS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preloadMarkerImage();
  }

  Future<void> _preloadMarkerImage() async {
    try {
      _cachedUserMarkerBytes = await MapHelpers.createUserMarkerBytes();
    } catch (e) {
      debugPrint('⚠️ خطأ في تحميل صورة الماركر: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _userAnnotation = null;
    _pointAnnotationManager = null;
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

  Future<void> _initAnnotationManager() async {
    if (_mapboxMap == null) return;
    _userAnnotation = null;
    _pointAnnotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();
  }

  Future<void> _updateUserMarker(double lat, double lng, double bearing) async {
    if (_pointAnnotationManager == null) return;

    final point = Point(coordinates: Position(lng, lat));

    if (_userAnnotation != null) {
      _userAnnotation!.geometry = point;
      _userAnnotation!.iconRotate = bearing;
      await _pointAnnotationManager?.update(_userAnnotation!);
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
    _userAnnotation = await _pointAnnotationManager?.create(options);
  }

  Future<void> _applyLabelLayersFilter() async {
    if (_mapboxMap == null) return;
    await MapHelpers.applyLabelLayersFilter(
      mapboxMap: _mapboxMap!,
      showPlaceLabels: _showPlaceLabels,
      showPoiLabels: _showPoiLabels,
      showRoadLabels: _showRoadLabels,
    );
  }

  Future<void> _changeMapStyle(String styleUri) async {
    if (_mapboxMap == null) return;
    setState(() {
      _currentMapStyle = styleUri;
    });
    await _mapboxMap?.loadStyleURI(styleUri);
    await _initAnnotationManager();
    await _applyLabelLayersFilter();
  }

  Future<void> _goToMyLocation() async {
    if (_mapboxMap == null) return;

    setState(() => _isLoadingLocation = true);

    try {
      final isGpsEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        _showSnackBar('⚠️ يرجى تفعيل خدمة الموقع (GPS) في جهازك.',
            isError: true);
        return;
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          _showSnackBar('⚠️ تم رفض صلاحية الموقع.', isError: true);
          return;
        }
      }
      if (permission == geo.LocationPermission.deniedForever) {
        _showSnackBar(
            '⚠️ تم رفض صلاحية الموقع نهائياً. يرجى تفعيلها من الإعدادات.',
            isError: true);
        return;
      }

      _locationSubscription?.cancel();

      geo.Position position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      double bearing = position.heading;
      if (bearing == 0.0 && position.speed > 0) {
        bearing = _currentBearing;
      }
      if (mounted) setState(() => _currentBearing = bearing);

      _mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
              coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
          bearing: bearing,
          pitch: 45.0,
        ),
      );
      await _updateUserMarker(position.latitude, position.longitude, bearing);

      _locationSubscription = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen((geo.Position pos) {
        if (mounted) {
          double newBearing = pos.heading;
          if (newBearing == 0.0 && pos.speed > 0) newBearing = _currentBearing;
          setState(() => _currentBearing = newBearing);

          _mapboxMap?.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(pos.longitude, pos.latitude)),
              zoom: 15.0,
              bearing: newBearing,
              pitch: 45.0,
            ),
          );
          _updateUserMarker(pos.latitude, pos.longitude, newBearing);
        }
      }, onError: (error) {
        debugPrint('خطأ في تحديث الموقع: $error');
      });

      _showSnackBar('📍 تم تحديد موقعك.', isError: false);
    } catch (e) {
      _showSnackBar('❌ تعذر تحديد موقعك، يرجى المحاولة لاحقاً.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _recenterCamera() {
    final driverProvider = context.read<DriverProvider>();
    final pos = driverProvider.currentPosition;
    if (pos == null) {
      _showSnackBar('⚠️ لا يوجد موقع محدد حالياً.', isError: true);
      return;
    }
    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 16.0,
        bearing: _currentBearing,
        pitch: 45.0,
      ),
    );
    _showSnackBar('🔄 تم إعادة التمركز.', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('driver_map'),
          onMapCreated: (map) {
            _mapboxMap = map;
            _initAnnotationManager();
            _mapboxMap?.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(35.9106, 31.9522)),
                zoom: 12.0,
              ),
            );
            _applyLabelLayersFilter();
          },
          styleUri: _currentMapStyle,
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
              _showSnackBar('🔄 تم تصفية الخط: $newRoute', isError: false);
            },
            onSearchSubmitted: (query) {
              _showSnackBar('🔍 جاري البحث عن: $query', isError: false);
            },
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
                onPressed: () {
                  showMapSettingsSheet(
                    context: context,
                    currentStyle: _currentMapStyle,
                    showPlaceLabels: _showPlaceLabels,
                    showPoiLabels: _showPoiLabels,
                    showRoadLabels: _showRoadLabels,
                    onStyleChanged: _changeMapStyle,
                    onApplyFilters: () {
                      setState(() {});
                      _applyLabelLayersFilter();
                    },
                    onTogglePlaceLabels: (val) =>
                        setState(() => _showPlaceLabels = val),
                    onTogglePoiLabels: (val) =>
                        setState(() => _showPoiLabels = val),
                    onToggleRoadLabels: (val) =>
                        setState(() => _showRoadLabels = val),
                  );
                },
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
                  _showSnackBar('📍 اضغط على الخريطة لإضافة نقطة (قيد التطوير)',
                      isError: false);
                },
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_location, size: 26),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Consumer2<DriverProvider, AuthProvider>(
            builder: (context, driverProvider, authProvider, _) {
              final user = authProvider.userData;
              final isOnline = driverProvider.isOnline; // ✅ استخدام آمن للمتغير

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            Text(
                              '🚗 مرحباً ${user?.fullName ?? "السائق"}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: isOnline ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'متاح' : 'غير متاح',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOnline ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '🧭 ${_currentBearing.toStringAsFixed(1)}°',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedRoute,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              driverProvider.toggleOnlineStatus();
                              _showSnackBar(
                                driverProvider.isOnline
                                    ? '🟢 أصبحت متاحاً للطلبات'
                                    : '🔴 تم إيقاف الاستقبال',
                                isError: false,
                              );
                            },
                            icon: Icon(
                              isOnline ? Icons.wifi : Icons.wifi_off,
                              size: 18,
                            ),
                            label: Text(isOnline ? 'متصل' : 'توصيل'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isOnline ? Colors.green : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (isOnline) {
                                driverProvider.startTrip();
                                _showSnackBar('🚀 تم بدء الرحلة!',
                                    isError: false);
                              } else {
                                _showSnackBar('⚠️ يجب أن تكون متاحاً أولاً.',
                                    isError: true);
                              }
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('بدء الرحلة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
          ),
        ),
      ],
    );
  }
}
