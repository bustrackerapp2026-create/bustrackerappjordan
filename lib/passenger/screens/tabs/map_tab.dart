import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import 'mixins/passenger_location_mixin.dart';

/// خريطة الراكب — واجهة خفيفة تعتمد على المكسينات المشتركة + مكسين الموقع.
///
/// الصلاحيات:
/// - MapCoreMixin: خريطة، طبقات، معالم POI، ستايل
/// - PickupPointMixin: عرض/إضافة نقاط التجمع + تأكيد/اقتراح تعديل
/// - PassengerLocationMixin: GPS + ماركر الراكب + البحث
///
/// لا يشمل صلاحيات الأدمن أو السائق (إدارة، رحلات، حذف نقاط).
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab>
    with
        WidgetsBindingObserver,
        MapCoreMixin<MapTab>,
        PickupPointMixin<MapTab>,
        PassengerLocationMixin<MapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;

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
    WidgetsBinding.instance.removeObserver(this);
    disposePassengerLocation();
    disposePickupPoints();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onPassengerLocationLifecycle(state);
  }

  @override
  void onStyleChanged() {
    listenToPickupPoints();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;
    final pickupId = findPickupIdByAnnotation(annotation);
    if (pickupId != null) {
      showPickupPointSheet(pickupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('passenger_map'),
          onMapCreated: (map) async {
            mapboxMap = map;
            await initAnnotationManager();
            await applyGoogleLikeCameraBehavior();
            mapboxMap?.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(35.9106, 31.9522)),
                zoom: 12.0,
                pitch: 0,
                bearing: 0,
              ),
            );
            applyMapConstraints();
            await Future<void>.delayed(const Duration(milliseconds: 400));
            await applyLabelLayersFilter();
            listenToPickupPoints();
            if (mounted) setState(() => isMapReady = true);
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

        // شريط البحث
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SearchBarWidget(
            selectedRoute: _selectedRoute,
            routes: AppConstants.jordanRoutes,
            onRouteChanged: (newRoute) {
              setState(() => _selectedRoute = newRoute);
              MapUtils.showSnackBar(
                context,
                '🔄 تم تصفية الخط: $newRoute',
              );
            },
            onSearchSubmitted: searchPassengerPlace,
          ),
        ),

        // أزرار التحكم
        Positioned(
          bottom: 120,
          right: 16,
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
                        ? '📍 اضغط على الخريطة لإضافة نقطة جديدة'
                        : '❌ تم إلغاء إضافة النقطة',
                    isError: !isAddingPickupPoint,
                  );
                },
                backgroundColor:
                    isAddingPickupPoint ? Colors.red : Colors.white,
                foregroundColor:
                    isAddingPickupPoint ? Colors.white : AppTheme.primaryColor,
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

        // شريط ترحيب الراكب
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
                          'زاوية الاتجاه: ${currentPassengerBearing.toStringAsFixed(1)}°',
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
