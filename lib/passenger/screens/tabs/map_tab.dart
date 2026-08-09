import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:geolocator/geolocator.dart' as geo;

import '../../../core/theme/app_theme.dart';
import '../../../core/map/pickup_point_sheet.dart';
import '../../../core/pickup/pickup_point_manager.dart';
import '../../../core/pickup/pickup_marker_helper.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/pickup_point_model.dart';
import '../../../services/location_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../map/widgets/map_settings_sheet.dart';
import '../../../map/utils/map_helpers.dart';

Future<({String name, String pointType})?> showPickupPointPickerDialog({
  required BuildContext context,
}) async {
  final TextEditingController nameController = TextEditingController();
  String selectedType = 'passenger';

  return showDialog<({String name, String pointType})>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('إضافة نقطة تجمع جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم النقطة',
                hintText: 'مثل: مجمع الشمال',
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🚌 تجمع باصات'),
                    selected: selectedType == 'bus',
                    onSelected: (selected) {
                      if (selected) {
                        setDialogState(() => selectedType = 'bus');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🚶 تجمع ركاب'),
                    selected: selectedType == 'passenger',
                    onSelected: (selected) {
                      if (selected) {
                        setDialogState(() => selectedType = 'passenger');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم النقطة')),
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                (name: name, pointType: selectedType),
              );
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    ),
  );
}

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
  bool _isUpdatingMarker = false;
  String _selectedRoute = AppConstants.jordanRoutes.first;
  StreamSubscription<geo.Position>? _locationSubscription;

  bool _showPlaceLabels = true;
  bool _showPoiLabels = true;
  bool _showRoadLabels = true;
  String _currentMapStyle = MapboxStyles.MAPBOX_STREETS;
  double _currentBearing = 0.0;
  bool _isAddingPickupPoint = false;

  final PickupPointManager _pickupManager = PickupPointManager();
  final LocationService _locationService = LocationService();
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, String> _pickupAnnotationToPointId = {};
  StreamSubscription<QuerySnapshot>? _pickupPointsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _pickupPointsSubscription?.cancel();
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

    _pointAnnotationManager?.tapEvents(onTap: (annotation) async {
      final pickupId = _pickupAnnotationToPointId[annotation.id];
      if (pickupId != null) {
        await _showPickupPointSheet(pickupId);
      }
    });
  }

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

      await _clearUserMarker();
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
    _listenToPickupPoints();
  }

  Future<void> _goToMyLocation() async {
    if (_mapboxMap == null) return;
    if (!mounted) return;

    setState(() => _isLoadingLocation = true);

    try {
      final hasPermission = await _locationService.checkAndRequestPermission();
      if (!mounted) return;

      if (!hasPermission) {
        final deniedForever =
            await _locationService.isPermissionDeniedForever();
        if (deniedForever) {
          final shouldOpen = await _showPermissionDialog();
          if (shouldOpen == true) {
            await _locationService.openAppSettings();
          }
        } else {
          final serviceEnabled =
              await geo.Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            _showSnackBar(
              '⚠️ يرجى تفعيل خدمة الموقع من إعدادات الجهاز.',
              isError: true,
            );
            await _locationService.openLocationSettings();
          } else {
            _showSnackBar('⚠️ يرجى السماح بصلاحية الموقع.', isError: true);
          }
        }
        return;
      }

      _locationSubscription?.cancel();

      final lastKnown = await _locationService.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        await _moveCameraAndMarker(lastKnown);
      }

      final position = await _locationService.getCurrentPosition(
        preferHighAccuracy: true,
        timeout: const Duration(seconds: 15),
      );

      if (!mounted) return;

      if (position == null) {
        _showSnackBar(
          '❌ تعذر تحديد موقعك. تأكد من تفعيل GPS والخروج لمكان مفتوح إن أمكن.',
          isError: true,
        );
        return;
      }

      await _moveCameraAndMarker(position);

      _locationSubscription = _locationService
          .getPositionStream(distanceFilter: 5)
          .listen((geo.Position pos) {
        if (mounted) {
          _moveCameraAndMarker(pos, animate: false);
        }
      }, onError: (error) {
        debugPrint('خطأ في تحديث الموقع: $error');
      });

      if (mounted) {
        _showSnackBar('📍 تم تحديد موقعك بنجاح.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ تعذر تحديد موقعك. حاول مرة أخرى.', isError: true);
        debugPrint('خطأ تحديد الموقع: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _moveCameraAndMarker(
    geo.Position position, {
    bool animate = true,
  }) async {
    double bearing = position.heading;
    if (bearing == 0.0 && position.speed > 0) {
      bearing = _currentBearing;
    }

    if (mounted) {
      setState(() => _currentBearing = bearing);
    }

    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 15.0,
        bearing: bearing,
        pitch: 45.0,
      ),
    );

    await _updateUserMarker(position.latitude, position.longitude, bearing);
  }

  Future<bool?> _showPermissionDialog() async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تفعيل الموقع'),
        content: const Text(
          'لتحديد موقعك بدقة مثل خرائط جوجل، نحتاج إلى صلاحية الموقع.\n\n'
          'يمكنك السماح عند استخدام التطبيق أو فتح الإعدادات ومنح الصلاحية يدوياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
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

  /// مزامنة فورية لنقاط التجمع المعتمدة بنفس شكل خريطة الأدمن
  void _listenToPickupPoints() {
    _pickupPointsSubscription?.cancel();
    _pickupPointsSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;
      if (_pointAnnotationManager == null) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted || _pointAnnotationManager == null) return;
      }

      final incomingIds = snapshot.docs.map((d) => d.id).toSet();
      final existingIds = _pickupAnnotations.keys.toSet();

      for (final id in existingIds.difference(incomingIds)) {
        final annotation = _pickupAnnotations.remove(id);
        if (annotation != null) {
          try {
            await _pointAnnotationManager?.delete(annotation);
          } catch (_) {}
          _pickupAnnotationToPointId.remove(annotation.id);
        }
      }

      for (final doc in snapshot.docs) {
        if (!mounted) return;
        try {
          final point = PickupPointModel.fromFirestore(doc);
          if (point.latitude == 0.0 && point.longitude == 0.0) continue;

          final existing = _pickupAnnotations.remove(point.id);
          if (existing != null) {
            try {
              await _pointAnnotationManager?.delete(existing);
            } catch (_) {}
            _pickupAnnotationToPointId.remove(existing.id);
          }

          final bytes = await PickupMarkerHelper.createMarkerBytes(
            name: point.name,
            pointType: point.pointType,
            confirmationCount: point.confirmationCount,
          );
          if (bytes == null || !mounted) continue;

          final options = PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(point.longitude, point.latitude),
            ),
            image: bytes,
            iconSize: 1.05,
            iconAnchor: IconAnchor.BOTTOM,
          );

          final annotation = await _pointAnnotationManager?.create(options);
          if (annotation != null) {
            _pickupAnnotations[point.id] = annotation;
            _pickupAnnotationToPointId[annotation.id] = point.id;
          }
        } catch (e) {
          debugPrint('⚠️ خطأ رسم نقطة ${doc.id}: $e');
        }
      }
    }, onError: (e) {
      debugPrint('⚠️ خطأ في بث نقاط التجمع: $e');
    });
  }

  /// عرض البطاقة الموحّدة الجميلة لنقطة التجمع (نفس تصميم الأدمن والسائق)
  Future<void> _showPickupPointSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted || point == null) return;

    final user = Provider.of<AuthProvider>(context, listen: false).userId;
    final adderName = await PickupPointSheet.loadAdderName(point.addedBy);
    if (!mounted) return;

    final action = await PickupPointSheet.show(
      context: context,
      point: point,
      mode: PickupSheetMode.user,
      adderName: adderName,
    );

    if (!mounted || action == null || action == PickupSheetAction.close) return;

    if (action == PickupSheetAction.confirm && user != null) {
      try {
        await _pickupManager.confirmPickupPoint(
          pointId: pickupId,
          userId: user,
        );
        if (!mounted) return;
        _showSnackBar('✅ تم تأكيد هذه النقطة للمراجعة.', isError: false);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('❌ فشل تأكيد النقطة.', isError: true);
      }
      return;
    }

    if (action == PickupSheetAction.suggestEdit && user != null) {
      final controller = TextEditingController();
      final suggested = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'اقتراح تعديل النقطة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'اكتب ما تحتاجه من تعديل أو ملاحظة',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إرسال'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (suggested == null || suggested.isEmpty) return;
      try {
        await _pickupManager.updatePickupPoint(
          pointId: pickupId,
          data: {
            'reviewNote': 'تمت مراجعة النقطة من قبل مستخدم',
            'suggestedEdit': suggested,
          },
        );
        if (!mounted) return;
        _showSnackBar('📝 تم إرسال اقتراح التعديل للمراجعة.', isError: false);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('❌ فشل إرسال اقتراح التعديل.', isError: true);
      }
    }
  }

  Future<void> _handleAddPickupPoint(Point point) async {
    if (!_isAddingPickupPoint) return;
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('passenger_map'),
          onMapCreated: (map) async {
            _mapboxMap = map;
            await _initAnnotationManager();
            _mapboxMap?.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(35.9106, 31.9522)),
                zoom: 12.0,
              ),
            );
            await _applyLabelLayersFilter();
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
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'add_pickup_point',
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
                    _isAddingPickupPoint ? Colors.red : Colors.white,
                foregroundColor:
                    _isAddingPickupPoint ? Colors.white : AppTheme.primaryColor,
                elevation: 4,
                shape: const CircleBorder(),
                child: Icon(
                  _isAddingPickupPoint
                      ? Icons.close
                      : Icons.add_location_alt_rounded,
                ),
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
