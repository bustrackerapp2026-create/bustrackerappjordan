import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../core/map/map_layer_controller.dart';

class MapHelpers {
  static Uint8List? _cachedMarkerBytes;

  static Future<Uint8List> createUserMarkerBytes() async {
    if (_cachedMarkerBytes != null) return _cachedMarkerBytes!;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 80.0;

    canvas.drawColor(Colors.transparent, BlendMode.clear);

    final glowPaint = Paint()
      ..color = Colors.blue.shade500.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawCircle(const Offset(size / 2, size / 2), 24, glowPaint);

    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), 16, outerPaint);

    final innerPaint = Paint()
      ..color = Colors.blue.shade700
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), 12, innerPaint);

    final arrowPath = Path();
    arrowPath.moveTo(size / 2, size / 2 - 8);
    arrowPath.lineTo(size / 2 - 6, size / 2 + 6);
    arrowPath.lineTo(size / 2, size / 2 + 3);
    arrowPath.lineTo(size / 2 + 6, size / 2 + 6);
    arrowPath.close();

    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    _cachedMarkerBytes = byteData!.buffer.asUint8List();
    return _cachedMarkerBytes!;
  }

  /// يوجّه للتحكم الموحّد بالطبقات (اكتشاف ديناميكي من الستايل)
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
