import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/map_text_label.dart';
import '../../../../services/map_text_label_service.dart';

/// عرض التسميات النصية (أسماء شوارع وغيرها) على خريطة الأدمن.
mixin AdminTextLabelsMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final MapTextLabelService _textLabelService = MapTextLabelService();
  StreamSubscription<List<MapTextLabel>>? _textLabelsSub;

  final Map<String, PointAnnotation> _textLabelAnnotations = {};
  List<MapTextLabel> _textLabels = const [];
  bool _drawingTextLabels = false;
  bool showTextLabels = true;

  final ValueNotifier<int> textLabelsUiTick = ValueNotifier<int>(0);

  int get textLabelsCount => _textLabels.length;

  void listenToTextLabels() {
    _textLabelsSub?.cancel();
    _textLabelsSub = _textLabelService.watchApproved().listen(
      (list) {
        _textLabels = list;
        textLabelsUiTick.value++;
        unawaited(_drawTextLabels());
      },
      onError: (e) {
        MapUtils.log('admin text labels: $e', tag: 'AdminTextLabels');
      },
    );
  }

  Future<void> toggleTextLabelsVisibility() async {
    showTextLabels = !showTextLabels;
    textLabelsUiTick.value++;
    if (showTextLabels) {
      await _drawTextLabels();
    } else {
      await _clearTextLabelAnnotations();
    }
  }

  Future<void> redrawTextLabels() => _drawTextLabels();

  Future<void> _drawTextLabels() async {
    if (!showTextLabels || mapboxMap == null || pointAnnotationManager == null) {
      return;
    }
    if (_drawingTextLabels) return;
    _drawingTextLabels = true;
    try {
      await _clearTextLabelAnnotations();
      if (_textLabels.isEmpty) return;

      for (final label in _textLabels) {
        try {
          final ann = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(label.longitude, label.latitude),
              ),
              textField: label.text,
              textSize: label.fontSize,
              textColor: label.colorArgb,
              textHaloColor: 0xFFFFFFFF,
              textHaloWidth: 1.4,
              textRotate: label.rotation,
              textAnchor: TextAnchor.CENTER,
              textMaxWidth: 12,
              // بدون أيقونة — نص فقط مثل اسم شارع
              iconSize: 0.01,
            ),
          );
          _textLabelAnnotations[label.id] = ann;
        } catch (e) {
          MapUtils.log('text label ${label.id}: $e', tag: 'AdminTextLabels');
        }
      }
    } finally {
      _drawingTextLabels = false;
    }
  }

  Future<void> _clearTextLabelAnnotations() async {
    if (pointAnnotationManager == null || _textLabelAnnotations.isEmpty) {
      _textLabelAnnotations.clear();
      return;
    }
    for (final ann in _textLabelAnnotations.values) {
      try {
        await pointAnnotationManager!.delete(ann);
      } catch (_) {}
    }
    _textLabelAnnotations.clear();
  }

  String? findTextLabelIdByAnnotation(PointAnnotation annotation) {
    for (final e in _textLabelAnnotations.entries) {
      if (e.value.id == annotation.id) return e.key;
    }
    return null;
  }

  MapTextLabel? getTextLabelById(String id) {
    for (final m in _textLabels) {
      if (m.id == id) return m;
    }
    return null;
  }

  void disposeTextLabels() {
    _textLabelsSub?.cancel();
    _textLabelsSub = null;
    _textLabelAnnotations.clear();
    textLabelsUiTick.dispose();
  }
}
