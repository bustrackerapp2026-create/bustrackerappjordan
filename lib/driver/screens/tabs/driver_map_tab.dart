import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/pickup/pickup_point_dialog.dart';
import '../../../core/pickup/pickup_point_manager.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../map/widgets/map_settings_sheet.dart';
import '../../../map/utils/map_helpers.dart';
import '../../../driver/providers/driver_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/trip_service.dart';
import '../../../models/trip_model.dart';
import '../../../models/trip_status.dart';
import '../../../models/route_point.dart';
import '../../../services/location_service.dart';

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

  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _polylineAnnotation;

  // --- متغيرات الموقع والحالة ---
  bool _isLoadingLocation = false;
  bool _isProcessingTrip = false;
  String _selectedRoute = AppConstants.jordanRoutes.first;
  StreamSubscription<geo.Position>? _locationSubscription;
  double _currentBearing = 0.0;
  String? _currentTripId;

  // --- إعدادات الخريطة ---
  bool _showPlaceLabels = true;
  bool _showPoiLabels = true;
  bool _showRoadLabels = true;
  String _currentMapStyle = MapboxStyles.MAPBOX_STREETS;

  final TripService _tripService = TripService();
  final LocationService _locationService = LocationService();
  final PickupPointManager _pickupManager = PickupPointManager();
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, String> _pickupAnnotationToPointId = {};
  StreamSubscription<QuerySnapshot>? _pickupPointsSubscription;
  bool _isAddingPickupPoint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preloadMarkerImage();
    debugPrint('📍 DriverMapTab initState');
  }

  Future<void> _preloadMarkerImage() async {
    try {
      _cachedUserMarkerBytes = await MapHelpers.createUserMarkerBytes();
      debugPrint('✅ تم تحميل صورة الماركر');
    } catch (e) {
      debugPrint('⚠️ خطأ في تحميل صورة الماركر: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _pickupPointsSubscription?.cancel();
    _userAnnotation = null;
    _pointAnnotationManager = null;
    _polylineAnnotation = null;
    _polylineAnnotationManager = null;
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

    _pointAnnotationManager?.tapEvents(onTap: (annotation) async {
      final pickupId = _pickupAnnotationToPointId[annotation.id];
      if (pickupId != null) {
        await _showPickupPointSheet(pickupId);
      }
    });
  }

  Future<void> _initPolylineManager() async {
    if (_mapboxMap == null) return;
    _polylineAnnotationManager =
        await _mapboxMap?.annotations.createPolylineAnnotationManager();
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

  Future<void> _showRouteOnMap(List<RoutePoint> routePoints) async {
    if (_polylineAnnotationManager == null || routePoints.isEmpty) return;

    if (_polylineAnnotation != null) {
      await _polylineAnnotationManager?.delete(_polylineAnnotation!);
      _polylineAnnotation = null;
    }

    final positions =
        routePoints.map((p) => Position(p.longitude, p.latitude)).toList();

    final options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: positions),
      lineColor: Colors.blue.toARGB32(),
      lineWidth: 4.0,
      lineOpacity: 0.8,
    );

    _polylineAnnotation = await _polylineAnnotationManager?.create(options);
    debugPrint(
        '✅ تم رسم المسار على الخريطة - عدد النقاط: ${routePoints.length}');
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
    await _initPolylineManager();
    await _applyLabelLayersFilter();
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    final result = await _locationService.searchPlace(query);
    if (result == null) {
      _showSnackBar('⚠️ لم يتم العثور على المكان.', isError: true);
      return;
    }
    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(result.longitude, result.latitude)),
        zoom: 15.0,
        bearing: _currentBearing,
        pitch: 45.0,
      ),
    );
    _showSnackBar('🔎 تم الانتقال إلى ${result.name}', isError: false);
  }

  Future<void> _goToMyLocation() async {
    if (_mapboxMap == null) return;

    setState(() => _isLoadingLocation = true);

    try {
      final hasPermission = await _locationService.checkAndRequestPermission();
      if (!hasPermission) {
        _showSnackBar('⚠️ يرجى تفعيل خدمة الموقع وإعطاء الصلاحية.',
            isError: true);
        return;
      }

      _locationSubscription?.cancel();

      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        _showSnackBar('⚠️ تعذر الحصول على الموقع الحالي.', isError: true);
        return;
      }

      debugPrint(
          '📍 تم جلب الموقع: ${position.latitude}, ${position.longitude}');

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

          _mapboxMap?.setCamera(
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
        debugPrint('خطأ في تحديث الموقع: $error');
      });

      _showSnackBar('📍 تم تحديد موقعك.', isError: false);
    } catch (e) {
      debugPrint('❌ خطأ في تحديد الموقع: $e');
      _showSnackBar('❌ تعذر تحديد موقعك.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _listenToPickupPoints() {
    _pickupPointsSubscription?.cancel();
    _pickupPointsSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .snapshots()
        .listen((snapshot) async {
      if (!mounted || _pointAnnotationManager == null) return;

      for (final annotation in _pickupAnnotations.values) {
        await _pointAnnotationManager?.delete(annotation);
      }
      _pickupAnnotations.clear();
      _pickupAnnotationToPointId.clear();

      for (final doc in snapshot.docs) {
        final point = doc.data();
        final latitude = (point['latitude'] as num?)?.toDouble();
        final longitude = (point['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;

        final options = PointAnnotationOptions(
          geometry: Point(coordinates: Position(longitude, latitude)),
          image: await MapHelpers.createUserMarkerBytes(),
          iconSize: 0.8,
          iconAnchor: IconAnchor.BOTTOM,
        );
        final annotation = await _pointAnnotationManager?.create(options);
        if (annotation != null) {
          _pickupAnnotations[doc.id] = annotation;
          _pickupAnnotationToPointId[annotation.id] = doc.id;
        }
      }
    });
  }

  Future<void> _showPickupPointSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted || point == null) return;

    final user = context.read<AuthProvider>().userId;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(point.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(point.pointType == 'passenger' ? 'تجمع ركاب' : 'تجمع باصات'),
              if (point.reviewNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('ملاحظات المراجعة: ${point.reviewNote}',
                      style: const TextStyle(color: Colors.orange)),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: user == null
                          ? null
                          : () => Navigator.pop(sheetContext, 'confirm'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('هذا صحيح'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: user == null
                          ? null
                          : () => Navigator.pop(sheetContext, 'edit'),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('أحتاج تعديل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'confirm' && user != null) {
      try {
        await _pickupManager.confirmPickupPoint(
            pointId: pickupId, userId: user);
        _showSnackBar('✅ تم تأكيد هذه النقطة للمراجعة.', isError: false);
      } catch (e) {
        _showSnackBar('❌ فشل تأكيد النقطة.', isError: true);
      }
      return;
    }

    if (action == 'edit' && user != null) {
      final controller = TextEditingController();
      final suggested = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('اقتراح تعديل النقطة'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'اكتب ما تحتاجه من تعديل أو ملاحظة'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('إرسال')),
          ],
        ),
      );
      if (suggested == null || suggested.isEmpty) return;
      try {
        await _pickupManager.updatePickupPoint(
          pointId: pickupId,
          data: {
            'reviewNote': 'تمت مراجعة النقطة من قبل مستخدم',
            'suggestedEdit': suggested,
          },
        );
        _showSnackBar('📝 تم إرسال اقتراح التعديل للمراجعة.', isError: false);
      } catch (e) {
        _showSnackBar('❌ فشل إرسال اقتراح التعديل.', isError: true);
      }
    }
  }

  Future<void> _handleAddPickupPoint(Point point) async {
    if (!_isAddingPickupPoint) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    final userData = authProvider.userData;
    if (userId == null || userData == null) {
      _showSnackBar('⚠️ يرجى تسجيل الدخول أولاً.', isError: true);
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    final result = await showPickupPointPickerDialog(context: context);
    if (!mounted || result == null || result.name.trim().isEmpty) {
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    try {
      await _pickupManager.addPickupPoint(
        name: result.name.trim(),
        latitude: point.coordinates.lat.toDouble(),
        longitude: point.coordinates.lng.toDouble(),
        userId: userId,
        userType: userData.userType,
        pointType: result.pointType,
      );
      _showSnackBar('✅ تم إرسال النقطة للمراجعة.', isError: false);
    } catch (e) {
      _showSnackBar('❌ فشل إضافة النقطة.', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingPickupPoint = false);
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

  // ✅ بدء الرحلة مع إنشاء معرف فريد من Firestore
  Future<void> _startTrip() async {
    if (_isProcessingTrip) return;

    final driverProvider = context.read<DriverProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;

    if (!driverProvider.isOnline) {
      _showSnackBar('⚠️ يجب أن تكون متاحاً أولاً.', isError: true);
      return;
    }
    if (driverProvider.isTripActive) {
      _showSnackBar('⚠️ الرحلة مفعلة بالفعل.', isError: true);
      return;
    }
    if (userId == null) {
      _showSnackBar('⚠️ يرجى تسجيل الدخول أولاً.', isError: true);
      return;
    }
    if (driverProvider.currentPosition == null) {
      _showSnackBar('⚠️ يرجى تحديد موقعك أولاً (اضغط على زر الموقع).',
          isError: true);
      return;
    }

    setState(() => _isProcessingTrip = true);

    try {
      // ✅ استخدام Firestore Auto ID
      final docRef = FirebaseFirestore.instance.collection('trips').doc();
      final tripId = docRef.id;
      debugPrint('📝 جاري إنشاء رحلة جديدة باستخدام ID: $tripId');

      final trip = TripModel(
        id: tripId,
        passengerId: '',
        driverId: userId,
        pickupPoint: 'نقطة البداية',
        dropoffPoint: 'الوجهة',
        createdAt: DateTime.now(),
        status: TripStatus.active,
        notes: 'رحلة بدأها السائق',
      );

      await _tripService.createTrip(trip);
      debugPrint('✅ تم إنشاء الرحلة في Firestore: $tripId');

      if (!mounted) return;

      setState(() {
        _currentTripId = tripId;
      });
      driverProvider.startTrip();
      _showSnackBar('🚀 تم بدء الرحلة!', isError: false);
    } catch (e) {
      debugPrint('❌ فشل إنشاء الرحلة: $e');
      if (mounted) {
        _showSnackBar('❌ فشل بدء الرحلة، يرجى المحاولة لاحقاً.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingTrip = false);
      }
    }
  }

  // ✅ إنهاء الرحلة مع التحقق من حجم المسار وتمرير driverId
  Future<void> _endTrip() async {
    if (_isProcessingTrip) return;

    final driverProvider = context.read<DriverProvider>();
    final authProvider = context.read<AuthProvider>();
    final driverId = authProvider.userId;

    if (!driverProvider.isTripActive) {
      _showSnackBar('⚠️ لا توجد رحلة نشطة.', isError: true);
      return;
    }
    if (_currentTripId == null) {
      _showSnackBar('⚠️ لا توجد رحلة نشطة للحفظ.', isError: true);
      return;
    }
    if (driverId == null) {
      _showSnackBar('⚠️ يرجى تسجيل الدخول أولاً.', isError: true);
      return;
    }

    setState(() => _isProcessingTrip = true);

    final route = driverProvider.endTrip();
    debugPrint('📍 عدد نقاط المسار: ${route.length}');

    try {
      // ✅ تحقق إضافي من عدد النقاط قبل الإرسال
      if (route.length > 5000) {
        throw Exception(
            'عدد نقاط المسار ($route.length) يتجاوز الحد الأقصى (5000).');
      }

      if (route.isNotEmpty) {
        debugPrint('💾 جاري حفظ المسار في Firestore...');
        // ✅ تمرير driverId للتحقق من الملكية
        await _tripService.updateTripStatus(
          _currentTripId!,
          TripStatus.completed,
          routePoints: route,
          driverId: driverId,
        );
        debugPrint('✅ تم حفظ المسار بنجاح');

        if (!mounted) return;

        await _showRouteOnMap(route);
        _showSnackBar('🏁 تم إنهاء الرحلة وحفظ المسار (${route.length} نقطة).',
            isError: false);
      } else {
        // ✅ تمرير driverId أيضاً عند عدم وجود مسار
        await _tripService.updateTripStatus(
          _currentTripId!,
          TripStatus.completed,
          driverId: driverId,
        );

        if (!mounted) return;

        _showSnackBar('🏁 تم إنهاء الرحلة (بدون مسار).', isError: false);
      }

      if (mounted) {
        setState(() {
          _currentTripId = null;
        });
      }
    } catch (e) {
      debugPrint('❌ فشل حفظ المسار: $e');
      if (mounted) {
        _showSnackBar('❌ فشل حفظ بيانات الرحلة على السيرفر.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingTrip = false);
      }
    }
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
            _initPolylineManager();
            _mapboxMap?.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(35.9106, 31.9522)),
                zoom: 12.0,
              ),
            );
            _applyLabelLayersFilter();
            _listenToPickupPoints();
          },
          styleUri: _currentMapStyle,
          // ignore: deprecated_member_use
          onTapListener: (event) {
            if (_isAddingPickupPoint) {
              _handleAddPickupPoint(event.point);
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
              _showSnackBar('🔄 تم تصفية الخط: $newRoute', isError: false);
            },
            onSearchSubmitted: (query) async {
              await _searchPlace(query);
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
                  setState(() => _isAddingPickupPoint = !_isAddingPickupPoint);
                  _showSnackBar(
                    _isAddingPickupPoint
                        ? '📍 اضغط على الخريطة لإضافة نقطة جديدة'
                        : '❌ تم إلغاء إضافة النقطة',
                    isError: !_isAddingPickupPoint,
                  );
                },
                backgroundColor:
                    _isAddingPickupPoint ? Colors.red : Colors.orange,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: Icon(
                    _isAddingPickupPoint ? Icons.close : Icons.add_location,
                    size: 26),
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
                                Text(
                                  '🚗 مرحباً ${user?.fullName ?? "السائق"}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.circle,
                                        size: 10,
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.red),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOnline ? 'متاح' : 'غير متاح',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.red,
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
                                  context
                                      .read<DriverProvider>()
                                      .toggleOnlineStatus();
                                  _showSnackBar(
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
                                onPressed: _isProcessingTrip
                                    ? null
                                    : (isTripActive ? _endTrip : _startTrip),
                                icon: _isProcessingTrip
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        isTripActive
                                            ? Icons.stop
                                            : Icons.play_arrow,
                                        size: 18),
                                label: Text(
                                  _isProcessingTrip
                                      ? 'جاري...'
                                      : (isTripActive ? 'إنهاء' : 'بدء الرحلة'),
                                ),
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
