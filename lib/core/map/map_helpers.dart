import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'map_layer_controller.dart';

/// واجهة مساعدة لطبقات خريطة Mapbox.
///
/// التطبيق الفعلي موحّد في [MapLayerController] لتفادي نسختين من المنطق.
class MapHelpers {
  /// إظهار/إخفاء تسميات الأماكن والمعالم والطرق.
  static Future<void> applyLabelLayersFilter({
    required MapboxMap mapboxMap,
    required bool showPlaceLabels,
    required bool showPoiLabels,
    required bool showRoadLabels,
  }) {
    return MapLayerController.applyLabelFilters(
      mapboxMap: mapboxMap,
      showPlaceLabels: showPlaceLabels,
      showPoiLabels: showPoiLabels,
      showRoadLabels: showRoadLabels,
    );
  }
}
