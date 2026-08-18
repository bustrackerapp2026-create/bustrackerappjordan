import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/landmark_marker_images.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/map_landmark.dart';
import '../../../../services/map_landmark_service.dart';

/// عرض معالم mapLandmarks المعتمدة على خريطة الأدمن (طبقة واحدة).
mixin AdminLandmarksMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final MapLandmarkService _landmarkService = MapLandmarkService();
  StreamSubscription<List<MapLandmark>>? _landmarksSub;

  final Map<String, PointAnnotation> _landmarkAnnotations = {};
  List<MapLandmark> _landmarks = const [];
  bool _drawingLandmarks = false;
  bool showLandmarks = true;

  final ValueNotifier<int> landmarksUiTick = ValueNotifier<int>(0);

  int get landmarksCount => _landmarks.length;

  void listenToLandmarks() {
    _landmarksSub?.cancel();
    _landmarksSub = _landmarkService.watchApproved().listen(
      (list) {
        _landmarks = list;
        landmarksUiTick.value++;
        unawaited(_drawLandmarks());
      },
      onError: (e) {
        MapUtils.log('admin landmarks: $e', tag: 'AdminLandmarks');
      },
    );
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

      final types = _landmarks.map((m) => m.type).toSet();
      final iconBytes = <MapLandmarkType, Uint8List>{};
      for (final t in types) {
        iconBytes[t] = await LandmarkMarkerImages.bytesFor(t);
      }
      if (pointAnnotationManager == null) return;

      for (final m in _landmarks) {
        final bytes = iconBytes[m.type];
        if (bytes == null) continue;
        try {
          final ann = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(m.longitude, m.latitude),
              ),
              image: bytes,
              iconSize: 0.85,
              iconAnchor: IconAnchor.CENTER,
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

  MapLandmark? getLandmarkById(String id) {
    for (final m in _landmarks) {
      if (m.id == id) return m;
    }
    return null;
  }

  void disposeLandmarks() {
    _landmarksSub?.cancel();
    _landmarksSub = null;
    _landmarkAnnotations.clear();
    landmarksUiTick.dispose();
  }
}
