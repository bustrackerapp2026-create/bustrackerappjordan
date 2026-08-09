import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'poi_info_card.dart';

/// نتيجة النقر على معلم من خريطة Mapbox
class MapPoiInfo {
  final String name;
  final String category;
  final String? rawClass;
  final String? rawType;
  final String layerId;
  final String? secondaryName;

  const MapPoiInfo({
    required this.name,
    required this.category,
    this.rawClass,
    this.rawType,
    required this.layerId,
    this.secondaryName,
  });
}

class MapLayerController {
  MapLayerController._();

  static const List<String> _placeKeywords = [
    'settlement',
    'place-label',
    'place_label',
    'state-label',
    'country-label',
    'continent-label',
    'district',
    'suburb',
    'neighbourhood',
    'neighborhood',
    'water-name',
    'waterway-label',
  ];

  static const List<String> _poiKeywords = [
    'poi',
    'airport-label',
    'transit',
    'rail-station',
    'bus-station',
    'medical',
    'education',
    'natural-point',
  ];

  static const List<String> _roadKeywords = [
    'road-label',
    'road_label',
    'street-label',
    'bridge-label',
    'tunnel-label',
    'motorway-junction',
    'path-label',
    'golf-hole-label',
  ];

  static const List<String> _fallbackPlace = [
    'settlement-label',
    'settlement-subdivision-label',
    'settlement-subdistrict-label',
    'state-label',
    'country-label',
    'continent-label',
    'water-name',
    'waterway-label',
  ];

  static const List<String> _fallbackPoi = [
    'poi-label',
    'airport-label',
    'transit-label',
  ];

  static const List<String> _fallbackRoad = [
    'road-label',
    'road-number-shield',
    'road-exit-shield',
    'bridge-label',
    'tunnel-label',
  ];

  static Future<void> applyLabelFilters({
    required MapboxMap mapboxMap,
    required bool showPlaceLabels,
    required bool showPoiLabels,
    required bool showRoadLabels,
  }) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final style = mapboxMap.style;
      final layers = await style.getStyleLayers();

      final placeIds = <String>{};
      final poiIds = <String>{};
      final roadIds = <String>{};

      for (final layer in layers) {
        final rawId = layer?.id;
        if (rawId == null || rawId.isEmpty) continue;
        final id = rawId;
        final lower = id.toLowerCase();

        if (_isBaseGeometryLayer(lower)) continue;

        if (_matchesAny(lower, _placeKeywords)) {
          placeIds.add(id);
        } else if (_matchesAny(lower, _poiKeywords)) {
          poiIds.add(id);
        } else if (_matchesAny(lower, _roadKeywords)) {
          roadIds.add(id);
        }
      }

      if (placeIds.isEmpty) placeIds.addAll(_fallbackPlace);
      if (poiIds.isEmpty) poiIds.addAll(_fallbackPoi);
      if (roadIds.isEmpty) roadIds.addAll(_fallbackRoad);

      var changed = 0;
      changed += await _setVisibilityBatch(style, placeIds, showPlaceLabels);
      changed += await _setVisibilityBatch(style, poiIds, showPoiLabels);
      changed += await _setVisibilityBatch(style, roadIds, showRoadLabels);

      _log(
        'طبقات محدّثة: $changed '
        '(أماكن: ${placeIds.length}, POI: ${poiIds.length}, شوارع: ${roadIds.length})',
      );
    } catch (e, st) {
      _log('فشل تطبيق فلاتر الطبقات: $e');
      if (kDebugMode) debugPrint('$st');
    }
  }

  static Future<MapPoiInfo?> queryPoiAt({
    required MapboxMap mapboxMap,
    required ScreenCoordinate screenCoordinate,
  }) async {
    try {
      final box = ScreenBox(
        min: ScreenCoordinate(
          x: screenCoordinate.x - 28,
          y: screenCoordinate.y - 28,
        ),
        max: ScreenCoordinate(
          x: screenCoordinate.x + 28,
          y: screenCoordinate.y + 28,
        ),
      );

      final geometry = RenderedQueryGeometry.fromScreenBox(box);
      final features = await mapboxMap.queryRenderedFeatures(
        geometry,
        RenderedQueryOptions(layerIds: null, filter: null),
      );

      if (features.isEmpty) return null;

      for (final item in features) {
        if (item == null) continue;

        final featureMap = item.queriedFeature.feature;
        final props = _asStringKeyedMap(featureMap['properties']);
        final layerIds = item.layers;

        final name = _extractName(props);
        if (name == null || name.isEmpty) continue;

        final clazzRaw = props['class'] ?? props['category_en'] ?? props['type'];
        final clazz = clazzRaw?.toString();
        final type = props['type']?.toString();
        final category = _categoryLabel(clazz, type, name);
        final layerId = _firstLayerId(layerIds);
        final secondary = _extractSecondaryName(props, name);

        return MapPoiInfo(
          name: name,
          category: category,
          rawClass: clazz,
          rawType: type,
          layerId: layerId,
          secondaryName: secondary,
        );
      }

      QueriedRenderedFeature? first;
      for (final f in features) {
        if (f != null) {
          first = f;
          break;
        }
      }
      if (first == null) return null;

      final props =
          _asStringKeyedMap(first.queriedFeature.feature['properties']);
      final fallbackName = props.values
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().length > 2)
          .take(1)
          .join();
      if (fallbackName.isEmpty) return null;

      return MapPoiInfo(
        name: fallbackName,
        category: 'مكان على الخريطة',
        layerId: _firstLayerId(first.layers),
      );
    } catch (e) {
      _log('فشل استعلام المعلم: $e');
      return null;
    }
  }

  /// يعرض البطاقة المخصصة من [PoiInfoCard]
  static void showPoiSheet(BuildContext context, MapPoiInfo info) {
    PoiInfoCard.show(context, info);
  }

  static String _firstLayerId(List<String?>? layerIds) {
    if (layerIds == null || layerIds.isEmpty) return 'map';
    for (final id in layerIds) {
      if (id != null && id.isNotEmpty) return id;
    }
    return 'map';
  }

  static Future<int> _setVisibilityBatch(
    StyleManager style,
    Set<String> layerIds,
    bool visible,
  ) async {
    var ok = 0;
    final value = visible ? 'visible' : 'none';
    for (final id in layerIds) {
      try {
        final exists = await style.styleLayerExists(id);
        if (!exists) continue;
        await style.setStyleLayerProperty(id, 'visibility', value);
        ok++;
      } catch (_) {}
    }
    return ok;
  }

  static bool _matchesAny(String lowerId, List<String> keywords) {
    for (final k in keywords) {
      if (lowerId.contains(k)) return true;
    }
    return false;
  }

  static bool _isBaseGeometryLayer(String lowerId) {
    const skip = [
      'land',
      'landuse',
      'water',
      'building',
      'road-primary',
      'road-secondary',
      'road-street',
      'road-minor',
      'road-motorway',
      'bridge-primary',
      'tunnel-primary',
      'hillshade',
      'landcover',
      'national-park',
    ];
    if (lowerId.contains('label') || lowerId.contains('poi')) return false;
    for (final s in skip) {
      if (lowerId.startsWith(s) || lowerId == s) return true;
    }
    return false;
  }

  static Map<String, dynamic> _asStringKeyedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
    return {};
  }

  static String? _extractName(Map<String, dynamic> props) {
    const keys = [
      'name_ar',
      'name:ar',
      'name',
      'name_en',
      'name:en',
      'name_int',
      'ref',
    ];
    for (final k in keys) {
      final v = props[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static String? _extractSecondaryName(
    Map<String, dynamic> props,
    String primary,
  ) {
    const keys = ['name_en', 'name:en', 'name_ar', 'name:ar', 'name'];
    for (final k in keys) {
      final v = props[k]?.toString().trim();
      if (v != null && v.isNotEmpty && v != primary) return v;
    }
    return null;
  }

  static String _categoryLabel(String? clazz, String? type, String name) {
    final c = (clazz ?? type ?? '').toLowerCase();
    if (c.contains('hospital') ||
        c.contains('clinic') ||
        c.contains('medical')) {
      return 'مستشفى / رعاية صحية';
    }
    if (c.contains('restaurant') || c.contains('cafe') || c.contains('food')) {
      return 'مطعم / مقهى';
    }
    if (c.contains('school') ||
        c.contains('college') ||
        c.contains('university')) {
      return 'مؤسسة تعليمية';
    }
    if (c.contains('fuel') || c.contains('parking')) {
      return 'محطة وقود / مواقف';
    }
    if (c.contains('bus') || c.contains('station') || c.contains('transit')) {
      return 'مواصلات عامة';
    }
    if (c.contains('shop') || c.contains('mall') || c.contains('store')) {
      return 'تسوق';
    }
    if (c.contains('mosque') ||
        c.contains('place_of_worship') ||
        c.contains('religion')) {
      return 'مكان عبادة';
    }
    if (c.contains('park') || c.contains('garden')) {
      return 'حديقة / متنزه';
    }
    if (c.isNotEmpty) return clazz ?? type ?? 'مكان';
    return 'مكان على الخريطة';
  }

  static void _log(String msg) {
    if (kDebugMode) debugPrint('🗺️ [MapLayers] $msg');
  }
}
