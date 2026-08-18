import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/landmark_marker_images.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/map_landmark.dart';
import '../../../../services/map_landmark_service.dart';

/// عرض معالم mapLandmarks مع سلوك زوم قريب من Google Maps:
/// - حجم أيقونة يتغيّر تدريجياً مع الزوم
/// - الاسم يظهر عند الاقتراب (زوم >= 13.5)
mixin AdminLandmarksMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final MapLandmarkService _landmarkService = MapLandmarkService();
  StreamSubscription<List<MapLandmark>>? _landmarksSub;

  final Map<String, PointAnnotation> _landmarkAnnotations = {};
  final Map<String, MapLandmark> _landmarkById = {};
  List<MapLandmark> _landmarks = const [];
  bool _drawingLandmarks = false;
  bool _updatingLandmarkScale = false;
  bool showLandmarks = true;

  double _lastLandmarkZoom = -1;
  Timer? _landmarkZoomDebounce;

  final ValueNotifier<int> landmarksUiTick = ValueNotifier<int>(0);

  int get landmarksCount => _landmarks.length;

  void listenToLandmarks() {
    _landmarksSub?.cancel();
    _landmarksSub = _landmarkService.watchApproved().listen(
      (list) {
        _landmarks = list;
        _landmarkById
          ..clear()
          ..addEntries(list.map((m) => MapEntry(m.id, m)));
        landmarksUiTick.value++;
        unawaited(_drawLandmarks());
      },
      onError: (e) {
        MapUtils.log('admin landmarks: $e', tag: 'AdminLandmarks');
      },
    );
  }

  /// يُستدعى من مستمع الكاميرا — يحدّث الحجم/الاسم حسب الزوم مثل Google Maps.
  void onCameraChangedForLandmarks() {
    _landmarkZoomDebounce?.cancel();
    _landmarkZoomDebounce = Timer(const Duration(milliseconds: 180), () {
      unawaited(_applyLandmarkScaleFromCamera());
    });
  }

  Future<void> _applyLandmarkScaleFromCamera() async {
    if (!showLandmarks ||
        mapboxMap == null ||
        pointAnnotationManager == null ||
        _landmarkAnnotations.isEmpty) {
      return;
    }
    try {
      final state = await mapboxMap!.getCameraState();
      final zoom = state.zoom;
      // تجاهل تغيّرات الزوم الصغيرة جداً لتقليل العمل
      if (_lastLandmarkZoom >= 0 && (zoom - _lastLandmarkZoom).abs() < 0.15) {
        return;
      }
      _lastLandmarkZoom = zoom;
      await _updateLandmarkAnnotationsStyle(zoom);
    } catch (e) {
      MapUtils.log('landmark zoom scale: $e', tag: 'AdminLandmarks');
    }
  }

  Future<void> _updateLandmarkAnnotationsStyle(double zoom) async {
    if (_updatingLandmarkScale || pointAnnotationManager == null) return;
    _updatingLandmarkScale = true;
    try {
      final iconSize = LandmarkMarkerImages.iconSizeForZoom(zoom);
      final showLabel = LandmarkMarkerImages.showLabelForZoom(zoom);
      final textSize = LandmarkMarkerImages.textSizeForZoom(zoom);
      final textOffset = LandmarkMarkerImages.textOffsetForZoom(zoom);

      for (final entry in _landmarkAnnotations.entries) {
        final id = entry.key;
        final ann = entry.value;
        final m = _landmarkById[id];
        if (m == null) continue;
        final name = m.name.trim();

        ann.iconSize = iconSize;
        if (showLabel && name.isNotEmpty) {
          ann.textField = name;
          ann.textSize = textSize;
          ann.textOffset = textOffset;
          ann.textColor = 0xFF212121;
          ann.textHaloColor = 0xFFFFFFFF;
          ann.textHaloWidth = 1.2;
          ann.textAnchor = TextAnchor.TOP;
          ann.textJustify = TextJustify.CENTER;
          ann.textMaxWidth = 10;
        } else {
          // إخفاء الاسم عند الزوم البعيد (مثل Google)
          ann.textField = '';
          ann.textSize = 0;
        }

        try {
          await pointAnnotationManager!.update(ann);
        } catch (_) {}
      }
    } finally {
      _updatingLandmarkScale = false;
    }
  }

  Future<void> toggleLandmarksVisibility() async {
    showLandmarks = !showLandmarks;
    landmarksUiTick.value++;
    if (showLandmarks) {
      await _drawLandmarks();
    } else {
      await _clearLandmarkAnnotations();
    }
  }

  Future<void> redrawLandmarks() => _drawLandmarks();

  Future<void> _drawLandmarks() async {
    if (!showLandmarks || mapboxMap == null || pointAnnotationManager == null) {
      return;
    }
    if (_drawingLandmarks) return;
    _drawingLandmarks = true;
    try {
      await _clearLandmarkAnnotations();
      if (_landmarks.isEmpty) return;

      LandmarkMarkerImages.clearCache();

      final types = _landmarks.map((m) => m.type).toSet();
      final iconBytes = <MapLandmarkType, Uint8List>{};
      for (final t in types) {
        iconBytes[t] = await LandmarkMarkerImages.bytesFor(t);
      }
      if (pointAnnotationManager == null) return;

      double zoom = 14;
      try {
        zoom = (await mapboxMap!.getCameraState()).zoom;
      } catch (_) {}
      _lastLandmarkZoom = zoom;

      final iconSize = LandmarkMarkerImages.iconSizeForZoom(zoom);
      final showLabel = LandmarkMarkerImages.showLabelForZoom(zoom);
      final textSize = LandmarkMarkerImages.textSizeForZoom(zoom);
      final textOffset = LandmarkMarkerImages.textOffsetForZoom(zoom);

      for (final m in _landmarks) {
        final bytes = iconBytes[m.type];
        if (bytes == null) continue;
        final name = m.name.trim();
        try {
          final ann = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(m.longitude, m.latitude),
              ),
              image: bytes,
              iconSize: iconSize,
              iconAnchor: IconAnchor.CENTER,
              textField: (showLabel && name.isNotEmpty) ? name : null,
              textSize: showLabel ? textSize : 0,
              textColor: 0xFF212121,
              textHaloColor: 0xFFFFFFFF,
              textHaloWidth: 1.2,
              textAnchor: TextAnchor.TOP,
              textOffset: textOffset,
              textMaxWidth: 10,
              textJustify: TextJustify.CENTER,
            ),
          );
          _landmarkAnnotations[m.id] = ann;
        } catch (e) {
          MapUtils.log('landmark ann ${m.id}: $e', tag: 'AdminLandmarks');
        }
      }
    } finally {
      _drawingLandmarks = false;
    }
  }

  Future<void> _clearLandmarkAnnotations() async {
    if (pointAnnotationManager == null || _landmarkAnnotations.isEmpty) {
      _landmarkAnnotations.clear();
      return;
    }
    for (final ann in _landmarkAnnotations.values) {
      try {
        await pointAnnotationManager!.delete(ann);
      } catch (_) {}
    }
    _landmarkAnnotations.clear();
  }

  String? findLandmarkIdByAnnotation(PointAnnotation annotation) {
    for (final e in _landmarkAnnotations.entries) {
      if (e.value.id == annotation.id) return e.key;
    }
    return null;
  }

  MapLandmark? getLandmarkById(String id) => _landmarkById[id];

  void disposeLandmarks() {
    _landmarkZoomDebounce?.cancel();
    _landmarkZoomDebounce = null;
    _landmarksSub?.cancel();
    _landmarksSub = null;
    _landmarkAnnotations.clear();
    _landmarkById.clear();
    landmarksUiTick.dispose();
  }
}
