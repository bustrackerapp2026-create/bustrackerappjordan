import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/map/map_constants.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_helpers.dart';

mixin MapCoreMixin<T extends StatefulWidget> on State<T> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  bool showPlaceLabels = true;
  bool showPoiLabels = true;
  bool showRoadLabels = true;
  String currentMapStyle = MapboxStyles.MAPBOX_STREETS;
  bool isMapReady = false;

  void onMapCreated(MapboxMap map) {
    mapboxMap = map;
    _initializeMap();
  }

  void _initializeMap() async {
    await initAnnotationManager();
    await initPolylineManager();
    applyMapConstraints();
    _setDefaultCamera();
    await applyLabelLayersFilter();
    if (mounted) setState(() => isMapReady = true);
    MapUtils.log('✅ تم إنشاء الخريطة بنجاح');
  }

  void _setDefaultCamera() {
    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(MapConstants.centerLng, MapConstants.centerLat),
        ),
        zoom: MapConstants.defaultZoom,
      ),
    );
  }

  void applyMapConstraints() {
    if (mapboxMap == null) return;
    try {
      mapboxMap?.setBounds(
        CameraBoundsOptions(
          bounds: CoordinateBounds(
            southwest: Point(
              coordinates: Position(MapConstants.minLng, MapConstants.minLat),
            ),
            northeast: Point(
              coordinates: Position(MapConstants.maxLng, MapConstants.maxLat),
            ),
            infiniteBounds: false,
          ),
        ),
      );
      MapUtils.log('✅ تم تحديد حدود الكاميرا (الأردن)');
    } catch (e) {
      MapUtils.log('⚠️ خطأ في تطبيق الحدود: $e');
    }
  }

  Future<void> initAnnotationManager() async {
    if (mapboxMap == null) return;
    try {
      if (pointAnnotationManager != null) {
        await mapboxMap?.annotations.removeAnnotationManager(
          pointAnnotationManager!,
        );
        pointAnnotationManager = null;
      }
      pointAnnotationManager =
          await mapboxMap?.annotations.createPointAnnotationManager();
      if (pointAnnotationManager != null) {
        pointAnnotationManager!.tapEvents(
          onTap: (annotation) {
            MapUtils.log('📍 تم النقر على العلامة: ${annotation.id}');
            handleAnnotationTap(annotation);
          },
        );
        MapUtils.log('✅ مدير العلامات جاهز');
      }
    } catch (e) {
      MapUtils.log('❌ خطأ في تهيئة PointAnnotationManager: $e');
    }
  }

  Future<void> initPolylineManager() async {
    if (mapboxMap == null) return;
    try {
      if (polylineAnnotationManager != null) {
        await mapboxMap?.annotations.removeAnnotationManager(
          polylineAnnotationManager!,
        );
        polylineAnnotationManager = null;
      }
      polylineAnnotationManager =
          await mapboxMap?.annotations.createPolylineAnnotationManager();
      MapUtils.log('✅ مدير الخطوط جاهز');
    } catch (e) {
      MapUtils.log('❌ خطأ في تهيئة PolylineAnnotationManager: $e');
    }
  }

  Future<void> applyLabelLayersFilter() async {
    if (mapboxMap == null) return;
    await MapHelpers.applyLabelLayersFilter(
      mapboxMap: mapboxMap!,
      showPlaceLabels: showPlaceLabels,
      showPoiLabels: showPoiLabels,
      showRoadLabels: showRoadLabels,
    );
  }

  Future<void> changeMapStyle(String styleUri) async {
    if (mapboxMap == null) return;
    try {
      if (mounted) setState(() => currentMapStyle = styleUri);
      await mapboxMap?.loadStyleURI(styleUri);
      await initAnnotationManager();
      await initPolylineManager();
      await applyLabelLayersFilter();
      applyMapConstraints();
      MapUtils.log('✅ تم تغيير ستايل الخريطة إلى: $styleUri');
    } catch (e) {
      MapUtils.log('⚠️ خطأ في تغيير الستايل: $e');
    }
  }

  Color hexToColor(String hex) {
    return MapUtils.hexToColor(hex);
  }

  void handleAnnotationTap(PointAnnotation annotation) {}

  Widget buildLocationButton({
    required VoidCallback onPressed,
    bool isLoading = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return FloatingActionButton(
      heroTag: 'map_my_location_$hashCode',
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? Colors.white,
      foregroundColor: foregroundColor ?? AppTheme.primaryColor,
      elevation: 4,
      shape: const CircleBorder(),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2.5,
              ),
            )
          : const Icon(Icons.my_location, size: 28),
    );
  }

  void showMapSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '⚙️ إعدادات طبقات الخريطة',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'اختر ستايل المظهر:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStyleOption(
                        title: 'شوارع',
                        icon: Icons.map_outlined,
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                        setSheetState: setSheetState,
                      ),
                      _buildStyleOption(
                        title: 'قمر صناعي',
                        icon: Icons.satellite_alt_outlined,
                        styleUri: MapboxStyles.SATELLITE_STREETS,
                        setSheetState: setSheetState,
                      ),
                      _buildStyleOption(
                        title: 'طبيعة',
                        icon: Icons.landscape_outlined,
                        styleUri: MapboxStyles.OUTDOORS,
                        setSheetState: setSheetState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'تخصيص الأسماء والمعالم:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('📍 المدن والأماكن الكبرى'),
                    value: showPlaceLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (mounted) setState(() => showPlaceLabels = val);
                      setSheetState(() {});
                      applyLabelLayersFilter();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('🏛️ معالم الجذب (POI)'),
                    value: showPoiLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (mounted) setState(() => showPoiLabels = val);
                      setSheetState(() {});
                      applyLabelLayersFilter();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('🛣️ أسماء الشوارع'),
                    value: showRoadLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (mounted) setState(() => showRoadLabels = val);
                      setSheetState(() {});
                      applyLabelLayersFilter();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStyleOption({
    required String title,
    required IconData icon,
    required String styleUri,
    required StateSetter setSheetState,
  }) {
    final isSelected = currentMapStyle == styleUri;
    return SizedBox(
      width: 95,
      child: InkWell(
        onTap: () {
          setSheetState(() {});
          changeMapStyle(styleUri);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMapWidget({Key? key}) {
    return MapWidget(
      key: key ?? const ValueKey('map_widget'),
      onMapCreated: onMapCreated,
      styleUri: currentMapStyle,
    );
  }
}
