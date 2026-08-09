import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// نتيجة النقر على معلم من خريطة Mapbox (مطعم / مستشفى / ...)
class MapPoiInfo {
  final String name;
  final String category;
  final String? rawClass;
  final String? rawType;
  final String layerId;

  const MapPoiInfo({
    required this.name,
    required this.category,
    this.rawClass,
    this.rawType,
    required this.layerId,
  });
}

/// تحكم موحّد بطبقات التسميات والمعالم لجميع الخرائط (أدمن / سائق / راكب).
///
/// يكتشف الطبقات من الستايل الحالي بدل الاعتماد على أسماء ثابتة فقط،
/// حتى تعمل المفاتيح فعلياً على Streets / Outdoors / Satellite Streets.
class MapLayerController {
  MapLayerController._();

  // كلمات مفتاحية لتصنيف طبقات التسمية حسب id أو source-layer
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

  /// طبقات احتياطية معروفة في Mapbox Streets v8 إن فشل الاكتشاف الديناميكي
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

  /// تطبيق إظهار/إخفاء طبقات الأسماء والمعالم
  static Future<void> applyLabelFilters({
    required MapboxMap mapboxMap,
    required bool showPlaceLabels,
    required bool showPoiLabels,
    required bool showRoadLabels,
  }) async {
    try {
      // انتظار بسيط حتى يكتمل تحميل طبقات الستايل
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final style = mapboxMap.style;
      final layers = await style.getStyleLayers();

      final placeIds = <String>{};
      final poiIds = <String>{};
      final roadIds = <String>{};

      for (final layer in layers) {
        final id = layer?.id;
        if (id == null || id.isEmpty) continue;
        final lower = id.toLowerCase();

        // تجاهل طبقات الرسم الأساسية (طرق/مباني) — نهتم بالتسميات فقط
        if (_isBaseGeometryLayer(lower)) continue;

        if (_matchesAny(lower, _placeKeywords)) {
          placeIds.add(id);
        } else if (_matchesAny(lower, _poiKeywords)) {
          poiIds.add(id);
        } else if (_matchesAny(lower, _roadKeywords)) {
          roadIds.add(id);
        }
      }

      // إن لم يُكتشف شيء، استخدم القائمة الاحتياطية
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

  /// الاستعلام عن معلم عند النقر على الخريطة
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

      // أولاً: كل الطبقات الظاهرة ثم نرشّح المعالم المفيدة
      final features = await mapboxMap.queryRenderedFeatures(
        geometry,
        RenderedQueryOptions(layerIds: null, filter: null),
      );

      if (features.isEmpty) return null;

      for (final item in features) {
        if (item == null) continue;
        final qf = item.queriedFeature;
        final featureMap = qf.feature;
        final props = _asStringKeyedMap(featureMap['properties']);
        final layerIds = item.layers;

        final name = _extractName(props);
        if (name == null || name.isEmpty) continue;

        final clazz = (props['class'] ?? props['category_en'] ?? props['type'])
            ?.toString();
        final type = props['type']?.toString();
        final category = _categoryLabel(clazz, type, name);
        final layerId =
            (layerIds != null && layerIds.isNotEmpty) ? layerIds.first : 'map';

        // تجاهل تسميات المدن/الشوارع العامة إن أمكن والتركيز على POI
        final lowerLayer = layerId.toLowerCase();
        final looksLikePoi = lowerLayer.contains('poi') ||
            lowerLayer.contains('airport') ||
            lowerLayer.contains('transit') ||
            (clazz != null && clazz.isNotEmpty);

        if (!looksLikePoi && !_looksLikePoiName(name)) {
          // نقبل الاسم إن لم نجد أفضل
          return MapPoiInfo(
            name: name,
            category: category,
            rawClass: clazz,
            rawType: type,
            layerId: layerId,
          );
        }

        return MapPoiInfo(
          name: name,
          category: category,
          rawClass: clazz,
          rawType: type,
          layerId: layerId,
        );
      }

      // إن لم نجد اسماً واضحاً، أظهر أول خاصية مفيدة
      final first = features.first;
      if (first == null) return null;
      final props = _asStringKeyedMap(first.queriedFeature.feature['properties']);
      final fallbackName = props.values
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().length > 2)
          .take(1)
          .join();
      if (fallbackName.isEmpty) return null;
      return MapPoiInfo(
        name: fallbackName,
        category: 'معلم على الخريطة',
        layerId: first.layers?.isNotEmpty == true ? first.layers!.first : 'map',
      );
    } catch (e) {
      _log('فشل استعلام المعلم: $e');
      return null;
    }
  }

  /// عرض ورقة معلومات المعلم
  static void showPoiSheet(BuildContext context, MapPoiInfo info) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        _iconForCategory(info.category),
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            info.category,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (info.rawClass != null || info.rawType != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    [
                      if (info.rawClass != null) 'التصنيف: ${info.rawClass}',
                      if (info.rawType != null) 'النوع: ${info.rawType}',
                    ].join(' · '),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'طبقة الخريطة: ${info.layerId}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── مساعدات داخلية ─────────────────────────────────────────────

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
      } catch (_) {
        // طبقة غير موجودة أو غير قابلة للتعديل في هذا الستايل
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
    // لا تتخطّى إن كانت تسمية
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

  static String _categoryLabel(String? clazz, String? type, String name) {
    final c = (clazz ?? type ?? '').toLowerCase();
    if (c.contains('hospital') || c.contains('clinic') || c.contains('medical')) {
      return 'مستشفى / رعاية صحية';
    }
    if (c.contains('restaurant') || c.contains('cafe') || c.contains('food')) {
      return 'مطعم / مقهى';
    }
    if (c.contains('school') || c.contains('college') || c.contains('university')) {
      return 'تعليمؤسسة تعليمية';
    }
    if (c.contains('fuel') || c.contains('parking')) {
      return 'محطة / مواقف';
    }
    if (c.contains('bus') || c.contains('station') || c.contains('transit')) {
      return 'مواصلات عامة';
    }
    if (c.contains('shop') || c.contains('mall') || c.contains('store')) {
      return 'تسوق';
    }
    if (c.contains('mosque') || c.contains('place_of_worship') || c.contains('religion')) {
      return 'مكان عبادة';
    }
    if (c.contains('park') || c.contains('garden')) {
      return 'حديقة / متنزه';
    }
    if (c.isNotEmpty) return clazz ?? type ?? 'معلم';
    return 'معلم على الخريطة';
  }

  static bool _looksLikePoiName(String name) {
    final n = name.toLowerCase();
    return n.contains('مستشفى') ||
        n.contains('مطعم') ||
        n.contains('مقهى') ||
        n.contains('مسجد') ||
        n.contains('جامعة') ||
        n.contains('مول') ||
        n.contains('hospital') ||
        n.contains('restaurant');
  }

  static IconData _iconForCategory(String category) {
    if (category.contains('مستشفى')) return Icons.local_hospital_outlined;
    if (category.contains('مطعم')) return Icons.restaurant_outlined;
    if (category.contains('تعليمليم')) return Icons.school_outlined;
    if (category.contains('مواصلات')) return Icons.directions_bus_outlined;
    if (category.contains('تسوق')) return Icons.storefront_outlined;
    if (category.contains('عبادة')) return Icons.mosque_outlined;
    if (category.contains('حديقة')) return Icons.park_outlined;
    return Icons.place_outlined;
  }

  static void _log(String msg) {
    if (kDebugMode) debugPrint('🗺️ [MapLayers] $msg');
  }
}
