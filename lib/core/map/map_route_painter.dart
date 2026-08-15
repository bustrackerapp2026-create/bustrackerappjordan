import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import 'map_constants.dart';

/// رسّام موحّد لخطوط المسارات: حد أبيض خفيف + خط ملوّن واضح.
class MapRoutePainter {
  MapRoutePainter._();

  /// يحوّل لون Flutter أو int ARGB إلى قيمة Mapbox
  static int toMapboxColor(Color color) => color.toARGB32();

  static int parseHexColor(String? hex, {int fallback = MapConstants.defaultRouteColor}) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final code = hex.replaceAll('#', '');
      if (code.length == 6) {
        return int.parse('FF$code', radix: 16);
      }
      if (code.length == 8) {
        return int.parse(code, radix: 16);
      }
    } catch (_) {}
    return fallback;
  }

  /// خط أساسي + حد خارجي لظهور أوضح فوق الخريطة
  static List<PolylineAnnotationOptions> buildDualStroke({
    required List<Position> coordinates,
    required int lineColor,
    double lineWidth = MapConstants.routeLineWidth,
    double outlineWidth = MapConstants.routeOutlineWidth,
    double lineOpacity = MapConstants.routeLineOpacity,
    double outlineOpacity = MapConstants.routeOutlineOpacity,
  }) {
    if (coordinates.length < 2) return const [];

    final geometry = LineString(coordinates: coordinates);

    return [
      PolylineAnnotationOptions(
        geometry: geometry,
        lineColor: MapConstants.routeOutlineColor,
        lineWidth: outlineWidth,
        lineOpacity: outlineOpacity,
      ),
      PolylineAnnotationOptions(
        geometry: geometry,
        lineColor: lineColor,
        lineWidth: lineWidth,
        lineOpacity: lineOpacity,
      ),
    ];
  }
}
