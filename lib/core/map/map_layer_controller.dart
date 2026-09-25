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

  static final Map<String, _LayerIdCache> _layerCache = {};

  /// مجموعات خطوط Mapbox الشائعة التي تدعم العربية
  /// (الترتيب: جرب الأولى ثم التالية عند الفشل)
  static const List<List<String>> arabicFontStacks = [
    ['Arial Unicode MS Regular', 'DIN Offc Pro Regular'],
    ['DIN Offc Pro Regular', 'Arial Unicode MS Regular'],
    ['Open Sans Regular', 'Arial Unicode MS Regular'],
    ['Roboto Regular', 'Arial Unicode MS Regular'],
    ['Klokantech Noto Sans Regular', 'Arial Unicode MS Regular'],
  ];

  static final List<dynamic> arabicTextFieldSimple = [
    'coalesce',
    ['get', 'name_ar'],
    ['get', 'name:ar'],
    ['get', 'name'],
    ['get', 'name_en'],
    ['get', 'name:en'],
    ['to-string', ['get', 'ref']],
  ];

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

  static const List<String> _labelKeywords = [
    'label',
    'poi',
    'place',
    'settlement',
    'road',
    'street',
    'bridge',
    'tunnel',
    'water-name',
    'waterway',
    'airport',
    'transit',
    'rail',
    'bus',
    'shield',
    'junction',
    'mountain',
    'natural',
    'housenum',
  ];

  static void invalidateCache([String? styleUri]) {
    if (styleUri == null) {
      _layerCache.clear();
    } else {
      _layerCache.remove(styleUri);
    }
  }

  static String _lastStyleKey = 'default';

  static Future<void> applyLabelFilters({
    required MapboxMap mapboxMap,
    required bool showPlaceLabels,
    required bool showPoiLabels,
    required bool showRoadLabels,
    String styleKey = 'default',
  }) async {
    try {
      _lastStyleKey = styleKey;
      final style = mapboxMap.style;
      var cache = _layerCache[styleKey];

      if (cache == null) {
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final layers = await style.getStyleLayers();
        final placeIds = <String>{};
        final poiIds = <String>{};
        final roadIds = <String>{};
        final allLabelIds = <String>{};

        for (final layer in layers) {
          final rawId = layer?.id;
          if (rawId == null || rawId.isEmpty) continue;
          final lower = rawId.toLowerCase();

          if (_isBaseGeometryLayer(lower)) continue;

          final isLabelLike =
              _matchesAny(lower, _labelKeywords) || lower.contains('label');

          if (isLabelLike) {
            allLabelIds.add(rawId);
          }

          if (_matchesAny(lower, _placeKeywords)) {
            placeIds.add(rawId);
          } else if (_matchesAny(lower, _poiKeywords)) {
            poiIds.add(rawId);
          } else if (_matchesAny(lower, _roadKeywords)) {
            roadIds.add(rawId);
          }
        }

        if (placeIds.isEmpty) placeIds.addAll(_fallbackPlace);
        if (poiIds.isEmpty) poiIds.addAll(_fallbackPoi);
        if (roadIds.isEmpty) roadIds.addAll(_fallbackRoad);

        allLabelIds.addAll(placeIds);
        allLabelIds.addAll(poiIds);
        allLabelIds.addAll(roadIds);

        cache = _LayerIdCache(
          placeIds: placeIds,
          poiIds: poiIds,
          roadIds: roadIds,
          labelIds: allLabelIds,
        );
        _layerCache[styleKey] = cache;
      }

      await applyArabicLabels(
        mapboxMap: mapboxMap,
        layerIds: cache.labelIds,
      );

      final results = await Future.wait([
        _setVisibilityBatch(style, cache.placeIds, showPlaceLabels),
        _setVisibilityBatch(style, cache.poiIds, showPoiLabels),
        _setVisibilityBatch(style, cache.roadIds, showRoadLabels),
      ]);

      final changed = results.fold<int>(0, (a, b) => a + b);
      _log(
        'طبقات محدّثة: $changed '
        '(أماكن: ${cache.placeIds.length}, POI: ${cache.poiIds.length}, '
        'شوارع: ${cache.roadIds.length}, تسميات: ${cache.labelIds.length})',
      );
    } catch (e, st) {
      _log('فشل تطبيق فلاتر الطبقات: $e');
      if (kDebugMode) debugPrint('$st');
    }
  }

  /// يفرض الاسم العربي + خط يدعم العربية على كل طبقات التسميات.
  static Future<int> applyArabicLabels({
    required MapboxMap mapboxMap,
    Set<String>? layerIds,
  }) async {
    try {
      final style = mapboxMap.style;
      final ids = layerIds ?? await _discoverAllLabelLayerIds(style);
      if (ids.isEmpty) {
        _log('لا توجد طبقات تسميات لتعريبها');
        return 0;
      }

      final exprJson = jsonEncode(arabicTextFieldSimple);
      var ok = 0;
      final list = ids.toList();
      const batchSize = 8;

      for (var i = 0; i < list.length; i += batchSize) {
        final end =
            (i + batchSize > list.length) ? list.length : i + batchSize;
        final batch = list.sublist(i, end);
        final results = await Future.wait(batch.map((id) async {
          try {
            final exists = await style.styleLayerExists(id);
            if (!exists) return 0;

            // 1) حقل النص العربي
            try {
              await style.setStyleLayerProperty(id, 'text-field', exprJson);
            } catch (_) {
              await style.setStyleLayerProperty(
                id,
                'text-field',
                arabicTextFieldSimple,
              );
            }

            // 2) خط عربي — جرّب عدة مكدسات حتى ينجح واحد
            await _applyBestArabicFont(style, id);

            // 3) تباعد خفيف للقراءة
            try {
              await style.setStyleLayerProperty(id, 'text-letter-spacing', 0.01);
            } catch (_) {}

            return 1;
          } catch (_) {
            return 0;
          }
        }));
        for (final r in results) {
          ok += r;
        }
      }

      _log('تعريب التسميات + الخط: $ok / ${ids.length} طبقة');
      return ok;
    } catch (e) {
      _log('فشل تعريب التسميات: $e');
      return 0;
    }
  }

  static Future<void> _applyBestArabicFont(
    StyleManager style,
    String layerId,
  ) async {
    for (final stack in arabicFontStacks) {
      try {
        await style.setStyleLayerProperty(
          layerId,
          'text-font',
          jsonEncode(stack),
        );
        return;
      } catch (_) {
        try {
          await style.setStyleLayerProperty(layerId, 'text-font', stack);
          return;
        } catch (_) {
          // جرّب المكدس التالي
        }
      }
    }
  }

  static Future<Set<String>> _discoverAllLabelLayerIds(
    StyleManager style,
  ) async {
    final ids = <String>{};
    try {
      final layers = await style.getStyleLayers();
      for (final layer in layers) {
        final rawId = layer?.id;
        if (rawId == null || rawId.isEmpty) continue;
        final lower = rawId.toLowerCase();
        if (_isBaseGeometryLayer(lower)) continue;
        if (_matchesAny(lower, _labelKeywords) || lower.contains('label')) {
          ids.add(rawId);
        }
      }
    } catch (e) {
      _log('فشل اكتشاف طبقات التسميات: $e');
    }
    if (ids.isEmpty) {
      ids.addAll(_fallbackPlace);
      ids.addAll(_fallbackPoi);
      ids.addAll(_fallbackRoad);
    }
    return ids;
  }

  static Future<MapPoiInfo?> queryPoiAt({
    required MapboxMap mapboxMap,
    required ScreenCoordinate screenCoordinate,
  }) async {
    try {
      const half = 16.0;
      final box = ScreenBox(
        min: ScreenCoordinate(
          x: screenCoordinate.x - half,
          y: screenCoordinate.y - half,
        ),
        max: ScreenCoordinate(
          x: screenCoordinate.x + half,
          y: screenCoordinate.y + half,
        ),
      );

      final geometry = RenderedQueryGeometry.fromScreenBox(box);

      final poiLayers = _layerCache[_lastStyleKey]?.poiIds;
      final layerIds = (poiLayers != null && poiLayers.isNotEmpty)
          ? poiLayers.toList(growable: false)
          : null;

      final features = await mapboxMap.queryRenderedFeatures(
        geometry,
        RenderedQueryOptions(layerIds: layerIds, filter: null),
      );

      if (features.isEmpty) return null;

      for (final item in features) {
        if (item == null) continue;

        final featureMap = item.queriedFeature.feature;
        final props = _asStringKeyedMap(featureMap['properties']);
        final layerIdsFound = item.layers;

        final name = _extractName(props);
        if (name == null || name.isEmpty) continue;

        final clazzRaw = props['class'] ?? props['category_en'] ?? props['type'];
        final clazz = clazzRaw?.toString();
        final type = props['type']?.toString();
        final category = _categoryLabel(clazz, type, name);
        final layerId = _firstLayerId(layerIdsFound);
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
    final list = layerIds.toList();
    const batchSize = 12;
    for (var i = 0; i < list.length; i += batchSize) {
      final end = (i + batchSize > list.length) ? list.length : i + batchSize;
      final batch = list.sublist(i, end);
      final results = await Future.wait(batch.map((id) async {
        try {
          final exists = await style.styleLayerExists(id);
          if (!exists) return 0;
          await style.setStyleLayerProperty(id, 'visibility', value);
          return 1;
        } catch (_) {
          return 0;
        }
      }));
      for (final r in results) {
        ok += r;
      }
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

class _LayerIdCache {
  final Set<String> placeIds;
  final Set<String> poiIds;
  final Set<String> roadIds;
  final Set<String> labelIds;

  const _LayerIdCache({
    required this.placeIds,
    required this.poiIds,
    required this.roadIds,
    required this.labelIds,
  });
}
