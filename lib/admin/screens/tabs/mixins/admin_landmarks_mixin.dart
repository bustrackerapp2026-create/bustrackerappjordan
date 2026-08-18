import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/landmark_marker_images.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/map_landmark.dart';
import '../../../../services/map_landmark_service.dart';

/// معالم الأدمن — نفس أسلوب Google Maps POI (حجم/خط/LOD).
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

  final Map<MapLandmarkType, Uint8List> _iconBytesCache = {};

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

  void onCameraChangedForLandmarks() {
    _landmarkZoomDebounce?.cancel();
    _landmarkZoomDebounce = Timer(const Duration(milliseconds: 160), () {
      unawaited(_applyLandmarkScaleFromCamera());
    });
  }

  Future<void> _applyLandmarkScaleFromCamera() async {
    if (!showLandmarks ||
        mapboxMap == null ||
        pointAnnotationManager == null) {
      return;
    }
    try {
      final zoom = (await mapboxMap!.getCameraState()).zoom;
      if (_lastLandmarkZoom >= 0 && (zoom - _lastLandmarkZoom).abs() < 0.12) {
        return;
      }
      final prev = _lastLandmarkZoom;
      _lastLandmarkZoom = zoom;

      if (prev < 0 || _lodSetChanged(prev, zoom)) {
        await _syncLandmarksForZoom(zoom);
      } else {
        await _updateLandmarkAnnotationsStyle(zoom);
      }
    } catch (e) {
      MapUtils.log('landmark zoom scale: $e', tag: 'AdminLandmarks');
    }
  }

  bool _lodSetChanged(double a, double b) {
    for (final t in MapLandmarkType.values) {
      if (LandmarkMarkerImages.isVisibleAtZoom(t, a) !=
          LandmarkMarkerImages.isVisibleAtZoom(t, b)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensureIconBytes(Iterable<MapLandmarkType> types) async {
    for (final t in types) {
      if (!_iconBytesCache.containsKey(t)) {
        _iconBytesCache[t] = await LandmarkMarkerImages.bytesFor(t);
      }
    }
  }

  PointAnnotationOptions _optionsFor(
    MapLandmark m,
    Uint8List bytes,
    double zoom,
  ) {
    final name = m.name.trim();
    final showLabel =
        LandmarkMarkerImages.showLabelAtZoom(m.type, zoom) && name.isNotEmpty;
    final textSize =
        showLabel ? LandmarkMarkerImages.textSizeForZoom(zoom) : 0.0;
    return PointAnnotationOptions(
      geometry: Point(coordinates: Position(m.longitude, m.latitude)),
      image: bytes,
      iconSize: LandmarkMarkerImages.iconSizeForZoom(zoom),
      iconAnchor: IconAnchor.CENTER,
      textField: showLabel ? name : null,
      textSize: textSize,
      textColor: LandmarkMarkerImages.labelTextColor,
      textHaloColor: LandmarkMarkerImages.labelHaloColor,
      textHaloWidth: LandmarkMarkerImages.labelHaloWidth,
      textLetterSpacing: LandmarkMarkerImages.labelLetterSpacing,
      textAnchor: TextAnchor.TOP,
      textOffset: LandmarkMarkerImages.textOffsetForZoom(zoom),
      textMaxWidth: LandmarkMarkerImages.labelMaxWidth,
      textJustify: TextJustify.CENTER,
    );
  }

  Future<void> _syncLandmarksForZoom(double zoom) async {
    if (_drawingLandmarks || pointAnnotationManager == null || !showLandmarks) {
      return;
    }
    _drawingLandmarks = true;
    try {
      final visible = _landmarks
          .where((m) => LandmarkMarkerImages.isVisibleAtZoom(m.type, zoom))
          .toList();
      final visibleIds = visible.map((m) => m.id).toSet();

      final toRemove = _landmarkAnnotations.keys
          .where((id) => !visibleIds.contains(id))
          .toList();
      for (final id in toRemove) {
        final ann = _landmarkAnnotations.remove(id);
        if (ann != null) {
          try {
            await pointAnnotationManager!.delete(ann);
          } catch (_) {}
        }
      }

      final missing = visible
          .where((m) => !_landmarkAnnotations.containsKey(m.id))
          .toList();
      if (missing.isNotEmpty) {
        await _ensureIconBytes(missing.map((m) => m.type).toSet());
        for (final m in missing) {
          final bytes = _iconBytesCache[m.type];
          if (bytes == null) continue;
          try {
            final ann =
                await pointAnnotationManager!.create(_optionsFor(m, bytes, zoom));
            _landmarkAnnotations[m.id] = ann;
          } catch (e) {
            MapUtils.log('landmark ann ${m.id}: $e', tag: 'AdminLandmarks');
          }
        }
      }

      await _updateLandmarkAnnotationsStyle(zoom);
    } finally {
      _drawingLandmarks = false;
    }
  }

  Future<void> _updateLandmarkAnnotationsStyle(double zoom) async {
    if (_updatingLandmarkScale || pointAnnotationManager == null) return;
    _updatingLandmarkScale = true;
    try {
      final iconSize = LandmarkMarkerImages.iconSizeForZoom(zoom);
      final textOffset = LandmarkMarkerImages.textOffsetForZoom(zoom);

      for (final entry in _landmarkAnnotations.entries) {
        final m = _landmarkById[entry.key];
        if (m == null) continue;
        final ann = entry.value;
        final name = m.name.trim();
        final showLabel =
            LandmarkMarkerImages.showLabelAtZoom(m.type, zoom) &&
                name.isNotEmpty;
        final textSize =
            showLabel ? LandmarkMarkerImages.textSizeForZoom(zoom) : 0.0;

        ann.iconSize = iconSize;
        if (showLabel) {
          ann.textField = name;
          ann.textSize = textSize;
          ann.textOffset = textOffset;
          ann.textColor = LandmarkMarkerImages.labelTextColor;
          ann.textHaloColor = LandmarkMarkerImages.labelHaloColor;
          ann.textHaloWidth = LandmarkMarkerImages.labelHaloWidth;
          ann.textLetterSpacing = LandmarkMarkerImages.labelLetterSpacing;
          ann.textAnchor = TextAnchor.TOP;
          ann.textJustify = TextJustify.CENTER;
          ann.textMaxWidth = LandmarkMarkerImages.labelMaxWidth;
        } else {
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
      LandmarkMarkerImages.clearCache();
      _iconBytesCache.clear();

      await _clearLandmarkAnnotations();
      if (_landmarks.isEmpty) return;

      double zoom = 14;
      try {
        zoom = (await mapboxMap!.getCameraState()).zoom;
      } catch (_) {}
      _lastLandmarkZoom = zoom;

      final visible = _landmarks
          .where((m) => LandmarkMarkerImages.isVisibleAtZoom(m.type, zoom))
          .toList();
      if (visible.isEmpty) return;

      await _ensureIconBytes(visible.map((m) => m.type).toSet());
      if (pointAnnotationManager == null) return;

      for (final m in visible) {
        final bytes = _iconBytesCache[m.type];
        if (bytes == null) continue;
        try {
          final ann =
              await pointAnnotationManager!.create(_optionsFor(m, bytes, zoom));
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
    _iconBytesCache.clear();
    landmarksUiTick.dispose();
  }
}
