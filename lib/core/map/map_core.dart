import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../core/theme/app_theme.dart';
import 'map_constants.dart';
import 'map_layer_controller.dart';
import 'map_utils.dart';

mixin MapCoreMixin<T extends StatefulWidget> on State<T> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  bool showPlaceLabels = true;
  bool showPoiLabels = true;
  bool showRoadLabels = true;

  /// يُحمَّل الستايل برمجياً فقط — لا نمرّر styleUri متغيّر في build
  /// حتى لا تُعاد تهيئة الخريطة عند كل setState.
  static const String initialMapStyle = MapboxStyles.MAPBOX_STREETS;
  String currentMapStyle = initialMapStyle;
  bool isMapReady = false;

  bool get suppressPoiTap => false;

  void onMapCreated(MapboxMap map) {
    mapboxMap = map;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await initAnnotationManager();
    await initPolylineManager();
    await applyStableGestures();
    await applyZoomLimitsOnly();
    _setDefaultCamera();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await applyLabelLayersFilter();
    if (mounted) setState(() => isMapReady = true);
    MapUtils.log('✅ تم إنشاء الخريطة بنجاح');
  }

  /// إيماءات بسيطة ومستقرة — بدون تدوير/ميلان/quickZoom
  Future<void> applyStableGestures() async {
    if (mapboxMap == null) return;
    try {
      await mapboxMap!.gestures.updateSettings(
        GesturesSettings(
          pitchEnabled: false,
          rotateEnabled: false,
          scrollEnabled: true,
          pinchToZoomEnabled: true,
          doubleTapToZoomInEnabled: true,
          doubleTouchToZoomOutEnabled: true,
          quickZoomEnabled: false,
          simultaneousRotateAndPinchToZoomEnabled: false,
          pinchPanEnabled: false,
          pinchToZoomDecelerationEnabled: true,
          scrollDecelerationEnabled: true,
          rotateDecelerationEnabled: false,
        ),
      );
    } catch (e) {
      MapUtils.log('⚠️ تعذر ضبط الإيماءات: $e');
    }
  }

  /// حدود زوم فقط — بدون قيود جغرافية صارمة (سبب شائع للرجّة)
  Future<void> applyZoomLimitsOnly() async {
    if (mapboxMap == null) return;
    try {
      await mapboxMap!.setBounds(
        CameraBoundsOptions(
          bounds: CoordinateBounds(
            southwest: Point(coordinates: Position(-180.0, -85.0)),
            northeast: Point(coordinates: Position(180.0, 85.0)),
            infiniteBounds: true,
          ),
          minZoom: MapConstants.minZoom,
          maxZoom: MapConstants.maxZoom,
          maxPitch: 0.0,
          minPitch: 0.0,
        ),
      );
      MapUtils.log('✅ تم ضبط حدود الزوم فقط (بدون قيود جغرافية)');
    } catch (e) {
      MapUtils.log('⚠️ خطأ في حدود الزوم: $e');
    }
  }

  /// توافق مع الاستدعاءات القديمة
  Future<void> applyGoogleLikeCameraBehavior() => applyStableGestures();
  Future<void> applyMapConstraints() => applyZoomLimitsOnly();

  Future<void> flyToFlat({
    required double latitude,
    required double longitude,
    double zoom = 15.5,
  }) async {
    if (mapboxMap == null) return;
    final clampedZoom = zoom.clamp(MapConstants.minZoom, MapConstants.maxZoom);
    await mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: clampedZoom.toDouble(),
        pitch: 0.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 800, startDelay: 0),
    );
  }

  Future<void> resetNorth() async {
    if (mapboxMap == null) return;
    final state = await mapboxMap!.getCameraState();
    await mapboxMap!.easeTo(
      CameraOptions(
        center: state.center,
        zoom: state.zoom,
        pitch: 0.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 350, startDelay: 0),
    );
  }

  void _setDefaultCamera() {
    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(MapConstants.centerLng, MapConstants.centerLat),
        ),
        zoom: MapConstants.defaultZoom,
        pitch: 0.0,
        bearing: 0.0,
      ),
    );
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
      }
    } catch (e) {
      MapUtils.log('❌ خطأ في PointAnnotationManager: $e');
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
    } catch (e) {
      MapUtils.log('❌ خطأ في PolylineAnnotationManager: $e');
    }
  }

  Future<void> applyLabelLayersFilter() async {
    if (mapboxMap == null) return;
    await MapLayerController.applyLabelFilters(
      mapboxMap: mapboxMap!,
      showPlaceLabels: showPlaceLabels,
      showPoiLabels: showPoiLabels,
      showRoadLabels: showRoadLabels,
    );
  }

  Future<void> changeMapStyle(String styleUri) async {
    if (mapboxMap == null) return;
    try {
      currentMapStyle = styleUri;
      await mapboxMap?.loadStyleURI(styleUri);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await initAnnotationManager();
      await initPolylineManager();
      await applyStableGestures();
      await applyLabelLayersFilter();
      await applyZoomLimitsOnly();
      onStyleChanged();
      if (mounted) setState(() {});
      MapUtils.log('✅ تم تغيير ستايل الخريطة');
    } catch (e) {
      MapUtils.log('⚠️ خطأ في تغيير الستايل: $e');
    }
  }

  void onStyleChanged() {}

  Color hexToColor(String hex) {
    try {
      final hexCode = hex.replaceAll('#', '');
      if (hexCode.length == 6) {
        return Color(int.parse('FF$hexCode', radix: 16));
      }
      if (hexCode.length == 8) {
        return Color(int.parse(hexCode, radix: 16));
      }
    } catch (e) {
      MapUtils.log('⚠️ خطأ في تحويل اللون: $e');
    }
    return Colors.blue;
  }

  void handleAnnotationTap(PointAnnotation annotation) {}

  Future<void> handleMapBackgroundTap(MapContentGestureContext gesture) async {
    if (!mounted || mapboxMap == null) return;
    if (suppressPoiTap) return;

    final poi = await MapLayerController.queryPoiAt(
      mapboxMap: mapboxMap!,
      screenCoordinate: gesture.touchPosition,
    );
    if (!mounted || poi == null) return;
    MapLayerController.showPoiSheet(context, poi);
  }

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

  Widget buildCompassButton() {
    return FloatingActionButton.small(
      heroTag: 'map_compass_$hashCode',
      onPressed: resetNorth,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 3,
      child: const Icon(Icons.explore_outlined, size: 22),
    );
  }

  void showMapSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
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
                    contentPadding: EdgeInsets.zero,
                    title: const Text('📍 المدن والأماكن الكبرى'),
                    value: showPlaceLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      setState(() => showPlaceLabels = val);
                      setSheetState(() {});
                      await applyLabelLayersFilter();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🏛️ معالم الجذب (POI)'),
                    value: showPoiLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      setState(() => showPoiLabels = val);
                      setSheetState(() {});
                      await applyLabelLayersFilter();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('🛣️ أسماء الشوارع'),
                    value: showRoadLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      setState(() => showRoadLabels = val);
                      setSheetState(() {});
                      await applyLabelLayersFilter();
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
}
