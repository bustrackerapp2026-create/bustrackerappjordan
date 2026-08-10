import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/map/map_core.dart';
import '../../../core/map/map_utils.dart';
import '../../../core/pickup/pickup_point_mixin.dart';
import '../../../core/trip/trip_manager_mixin.dart';
import '../../../map/widgets/search_bar_widget.dart';
import '../../../driver/providers/driver_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../services/location_service.dart';
import 'mixins/driver_location_mixin.dart';

/// خريطة السائق — واجهة خفيفة تعتمد على المكسينات المشتركة + مكسين الموقع.
///
/// الصلاحيات:
/// - MapCoreMixin: خريطة، طبقات، معالم POI، ستايل
/// - PickupPointMixin: عرض/إضافة نقاط التجمع + تأكيد/اقتراح تعديل
/// - TripManagerMixin: بدء/إنهاء الرحلة ورسم المسار
/// - DriverLocationMixin: GPS + ماركر السائق
///
/// لا يشمل صلاحيات الأدمن (إدارة سائقين، ركاب، مسارات، حذف نقاط).
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
        TripManagerMixin<DriverMapTab>,
        DriverLocationMixin<DriverMapTab> {
  String _selectedRoute = AppConstants.jordanRoutes.first;

  @override
  bool get suppressPoiTap => isAddingPickupPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    preloadDriverMarker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeDriverLocation();
    disposePickupPoints();
    disposeTripManager();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onDriverLocationLifecycle(state);
  }

  @override
  void onStyleChanged() {
    // بعد تغيير ستايل الخريطة نعيد رسم نقاط التجمع
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

  Future<void> _searchPlace(String query) async {
    if (!mounted) return;
    await MapUtils.searchPlace(
      context,
      mapboxMap,
      query,
      0,
      locationService,
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
            onRouteChanged: (r) => setState(() => _selectedRoute = r),
            onSearchSubmitted: _searchPlace,
          ),
        ),

        // أزرار التحكم
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
                onPressed: recenterDriverCamera,
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                child: const Icon(Icons.center_focus_strong),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'driver_my_location',
                onPressed: goToMyLocation,
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

        // لوحة حالة السائق والرحلة
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🚗 مرحباً ${user?.fullName ?? "السائق"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(state.isOnline ? 'متاح' : 'غير متاح'),
                    const SizedBox(height: 8),
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
