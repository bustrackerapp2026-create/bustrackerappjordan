import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:geolocator/geolocator.dart' as geo;

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../map/widgets/map_settings_sheet.dart';
import '../../../map/utils/map_helpers.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with WidgetsBindingObserver {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PointAnnotation? _userAnnotation;

  bool _isLoadingLocation = false;
  bool _isUpdatingMarker = false; // لمنع التضارب في إنشاء الماركر
  String _selectedRoute = AppConstants.jordanRoutes.first;
  StreamSubscription<geo.Position>? _locationSubscription;

  bool _showPlaceLabels = true;
  bool _showPoiLabels = true;
  bool _showRoadLabels = true;
  String _currentMapStyle = MapboxStyles.MAPBOX_STREETS;
  double _currentBearing = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _clearUserMarker();
    super.dispose();
  }

  Future<void> _clearUserMarker() async {
    if (_pointAnnotationManager != null && _userAnnotation != null) {
      try {
        await _pointAnnotationManager?.delete(_userAnnotation!);
      } catch (_) {}
      _userAnnotation = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLoadingLocation) {
      _goToMyLocation();
    }
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _locationSubscription?.cancel();
    }
  }

  Future<void> _initAnnotationManager() async {
    if (_mapboxMap == null) return;
    if (_pointAnnotationManager != null) {
      await _clearUserMarker();
    }
    _pointAnnotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();
  }

  /// 🚀 تحديث آمن وسريع لمؤشر المستخدم بدون سباق أو تكرار
  Future<void> _updateUserMarker(double lat, double lng, double bearing) async {
    if (_pointAnnotationManager == null || _isUpdatingMarker) return;
    _isUpdatingMarker = true;

    try {
      final bytes = await MapHelpers.createUserMarkerBytes();

      final options = PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        image: bytes,
        iconSize: 1.0,
        iconAnchor: IconAnchor.CENTER,
        iconRotate: bearing,
      );

      // تنظيف المؤشر القديم بأمان
      await _clearUserMarker();

      // إنشاء المؤشر الجديد
      _userAnnotation = await _pointAnnotationManager?.create(options);
    } catch (e) {
      debugPrint('خطأ أثناء تحديث ماركر الخريطة: $e');
    } finally {
      _isUpdatingMarker = false;
    }
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
        _showSnackBar('⚠️ تم رفض صلاحية الموقع نهائياً من الإعدادات.',
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

      if (mounted) {
        setState(() {
          _currentBearing = bearing;
        });
      }

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
          if (newBearing == 0.0 && pos.speed > 0) {
            newBearing = _currentBearing;
          }
          setState(() {
            _currentBearing = newBearing;
          });
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

      if (mounted) {
        _showSnackBar('📍 تم تحديد موقعك.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ تعذر تحديد موقعك: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('passenger_map'),
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
          bottom: 120,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'map_layers_settings',
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
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'my_location',
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
            ],
          ),
        ),
        Positioned(
          bottom: 30,
          left: 16,
          right: 16,
          child: Container(
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
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      radius: 18,
                      child: const Icon(Icons.directions_bus,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🚌 مرحباً أيها الراكب',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'زاوية الاتجاه: ${_currentBearing.toStringAsFixed(1)}°',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedRoute,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
