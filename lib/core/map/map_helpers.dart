import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// 🛠️ كلاس مساعدة للتحكم في طبقات وتكفيات خريطة Mapbox
class MapHelpers {
  /// ✅ دالة تطبيق فلاتر إظهار وإخفاء النصوص والمعالم على الخريطة
  static Future<void> applyLabelLayersFilter({
    required MapboxMap mapboxMap,
    required bool showPlaceLabels,
    required bool showPoiLabels,
    required bool showRoadLabels,
  }) async {
    try {
      final style = mapboxMap.style;
      final layers = await style.getStyleLayers();

      for (final layer in layers) {
        if (layer == null) continue;
        final layerId = layer.id;

        // 📍 1. طبقات أسماء المدن والدول والأماكن (Place Labels)
        if (_isPlaceLabelLayer(layerId)) {
          await style.setStyleLayerProperty(
            layerId,
            'visibility',
            showPlaceLabels ? 'visible' : 'none',
          );
        }
        // 🏛️ 2. طبقات معالم الجذب والمواقف (POI Labels)
        else if (_isPoiLabelLayer(layerId)) {
          await style.setStyleLayerProperty(
            layerId,
            'visibility',
            showPoiLabels ? 'visible' : 'none',
          );
        }
        // 🛣️ 3. طبقات أسماء الشوارع والطرق (Road Labels)
        else if (_isRoadLabelLayer(layerId)) {
          await style.setStyleLayerProperty(
            layerId,
            'visibility',
            showRoadLabels ? 'visible' : 'none',
          );
        }
      }

      if (kDebugMode) {
        debugPrint('✅ [MapHelpers] تم تطبيق فلاتر الطبقات بنجاح');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [MapHelpers] خطأ في تغيير طبقات الخريطة: $e');
      }
    }
  }

  // ─── 🔍 دوال مساعدة للتعرف على معرّفات الطبقات (Layer IDs) ───

  /// فحص ما إذا كانت الطبقة تتبع لأسماء المدن والمناطق
  static bool _isPlaceLabelLayer(String layerId) {
    final lower = layerId.toLowerCase();
    return lower.contains('settlement') ||
        lower.contains('place-label') ||
        lower.contains('country-label') ||
        lower.contains('state-label');
  }

  /// فحص ما إذا كانت الطبقة تتبع للمعالم والأنشطة Commercial / POI
  static bool _isPoiLabelLayer(String layerId) {
    final lower = layerId.toLowerCase();
    return lower.contains('poi-label') ||
        lower.contains('transit-label') ||
        lower.contains('airport-label');
  }

  /// فحص ما إذا كانت الطبقة تتبع لأسماء الطرق والشوارع
  static bool _isRoadLabelLayer(String layerId) {
    final lower = layerId.toLowerCase();
    return lower.contains('road-label') ||
        lower.contains('highway-label') ||
        lower.contains('path-label');
  }
}
