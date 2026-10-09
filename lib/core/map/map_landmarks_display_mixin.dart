import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../models/map_landmark.dart';
import '../../services/map_landmark_service.dart';
import 'landmark_marker_images.dart';
import 'map_core.dart';
import 'map_utils.dart';

/// عرض المعالم المعتمدة — الأسماء بخط Flutter العربي (RTL).
mixin MapLandmarksDisplayMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final MapLandmarkService _landmarksService = MapLandmarkService();
  StreamSubscription<List<MapLandmark>>? _landmarksDisplaySub;

  final Map<String, PointAnnotation> _displayLandmarkAnnotations = {};
  final Map<String, MapLandmark> _displayLandmarkById = {};
  List<MapLandmark> _displayLandmarks = const [];
  bool _drawingDisplayLandmarks = false;
  bool _updatingDisplayLandmarkScale = false;
  bool showDisplayLandmarks = true;

  double _lastDisplayLandmarkZoom = -1;
  Timer? _displayLandmarkZoomDebounce;

  int get displayLandmarksCount => _displayLandmarks.length;

  void listenToDisplayLandmarks() {
    _landmarksDisplaySub?.cancel();
    _landmarksDisplaySub = _landmarksService.watchApproved().listen(
      (list) {
        _displayLandmarks = list;
        _displayLandmarkById
          ..clear()
          ..addEntries(list.map((m) => MapEntry(m.id, m)));
        unawaited(redrawDisplayLandmarks());
      },
      onError: (e) {
        MapUtils.log('display landmarks: $e', tag: 'MapLandmarks');
      },
    );
  }

  void onCameraChangedForDisplayLandmarks() {
    _displayLandmarkZoomDebounce?.cancel();
    _displayLandmarkZoomDebounce = Timer(const Duration(milliseconds: 160), () {
      unawaited(_applyDisplayLandmarkScaleFromCamera());
    });
  }

  Future<void> _applyDisplayLandmarkScaleFromCamera() async {
    if (!showDisplayLandmarks ||
        mapboxMap == null ||
        pointAnnotationManager == null) {
      return;
    }
    try {
      final zoom = (await mapboxMap!.getCameraState()).zoom;
      if (_lastDisplayLandmarkZoom >= 0 &&
          (zoom - _lastDisplayLandmarkZoom).abs() < 0.12) {
        return;
      }
      final prev = _lastDisplayLandmarkZoom;
      _lastDisplayLandmarkZoom = zoom;

      if (prev < 0 || _lodSetChanged(prev, zoom)) {
        await _syncDisplayLandmarksForZoom(zoom);
      } else {
        await _updateDisplayLandmarkStyle(zoom);
      }
    } catch (e) {
      MapUtils.log('display landmark zoom: $e', tag: 'MapLandmarks');
    }
  }

  bool _lodSetChanged(double a, double b) {
    for (final t in MapLandmarkType.values) {
      if (LandmarkMarkerImages.isVisibleAtZoom(t, a) !=
          LandmarkMarkerImages.isVisibleAtZoom(t, b)) {
        return true;
      }
      if (LandmarkMarkerImages.showLabelAtZoom(t, a) !=
          LandmarkMarkerImages.showLabelAtZoom(t, b)) {
        return true;
      }
    }
    return false;
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

  Future<void> _syncDisplayLandmarksForZoom(double zoom) async {
    if (_drawingDisplayLandmarks ||
        pointAnnotationManager == null ||
        !showDisplayLandmarks) {
      return;
    }
    _drawingDisplayLandmarks = true;
    try {
      final visible = _displayLandmarks
          .where((m) => LandmarkMarkerImages.isVisibleAtZoom(m.type, zoom))
          .toList();
      final visibleIds = visible.map((m) => m.id).toSet();

      final toRemove = _displayLandmarkAnnotations.keys
          .where((id) => !visibleIds.contains(id))
          .toList();
      for (final id in toRemove) {
        final ann = _displayLandmarkAnnotations.remove(id);
        if (ann != null) {
          try {
            await pointAnnotationManager!.delete(ann);
          } catch (_) {}
        }
      }

      // أعد إنشاء الكل عند تغيّر مستوى التسمية لضمان صورة صحيحة
      final existing = _displayLandmarkAnnotations.keys.toList();
      for (final id in existing) {
        final ann = _displayLandmarkAnnotations.remove(id);
        if (ann != null) {
          try {
            await pointAnnotationManager!.delete(ann);
          } catch (_) {}
        }
      }

      for (final m in visible) {
        try {
          final bytes = await LandmarkMarkerImages.bytesFor(m.type);
          final ann = await pointAnnotationManager!.create(
            _optionsFor(m, bytes, zoom),
          );
          _displayLandmarkAnnotations[m.id] = ann;
        } catch (e) {
          MapUtils.log('display landmark ${m.id}: $e', tag: 'MapLandmarks');
        }
      }
    } finally {
      _drawingDisplayLandmarks = false;
    }
  }

  Future<void> _updateDisplayLandmarkStyle(double zoom) async {
    if (_updatingDisplayLandmarkScale || pointAnnotationManager == null) return;
    _updatingDisplayLandmarkScale = true;
    try {
      for (final entry in _displayLandmarkAnnotations.entries) {
        final m = _displayLandmarkById[entry.key];
        if (m == null) continue;
        final ann = entry.value;
        final name = m.name.trim();
        final showLabel =
            LandmarkMarkerImages.showLabelAtZoom(m.type, zoom) &&
                name.isNotEmpty;

        ann.iconSize = LandmarkMarkerImages.iconSizeForZoom(zoom);
        ann.iconAnchor = IconAnchor.CENTER;
        ann.textField = showLabel ? name : '';
        ann.textSize =
            showLabel ? LandmarkMarkerImages.textSizeForZoom(zoom) : 0.0;
        ann.textOffset = LandmarkMarkerImages.textOffsetForZoom(zoom);
        ann.textColor = LandmarkMarkerImages.labelTextColor;
        ann.textHaloColor = LandmarkMarkerImages.labelHaloColor;
        ann.textHaloWidth = LandmarkMarkerImages.labelHaloWidth;
        ann.textLetterSpacing = LandmarkMarkerImages.labelLetterSpacing;
        ann.textAnchor = TextAnchor.TOP;
        ann.textJustify = TextJustify.CENTER;
        ann.textMaxWidth = LandmarkMarkerImages.labelMaxWidth;

        try {
          await pointAnnotationManager!.update(ann);
        } catch (_) {}
      }
    } finally {
      _updatingDisplayLandmarkScale = false;
    }
  }

  Future<void> toggleDisplayLandmarksVisibility() async {
    showDisplayLandmarks = !showDisplayLandmarks;
    if (showDisplayLandmarks) {
      await redrawDisplayLandmarks();
    } else {
      await _clearDisplayLandmarkAnnotations();
    }
  }

  Future<void> redrawDisplayLandmarks() async {
    if (!showDisplayLandmarks ||
        mapboxMap == null ||
        pointAnnotationManager == null) {
      return;
    }
    if (_drawingDisplayLandmarks) return;
    _drawingDisplayLandmarks = true;
    try {
      LandmarkMarkerImages.clearCache();

      await _clearDisplayLandmarkAnnotations();
      if (_displayLandmarks.isEmpty) return;

      double zoom = 14;
      try {
        zoom = (await mapboxMap!.getCameraState()).zoom;
      } catch (_) {}
      _lastDisplayLandmarkZoom = zoom;

      final visible = _displayLandmarks
          .where((m) => LandmarkMarkerImages.isVisibleAtZoom(m.type, zoom))
          .toList();
      if (visible.isEmpty) return;

      for (final m in visible) {
        try {
          final bytes = await LandmarkMarkerImages.bytesFor(m.type);
          final ann = await pointAnnotationManager!.create(
            _optionsFor(m, bytes, zoom),
          );
          _displayLandmarkAnnotations[m.id] = ann;
        } catch (e) {
          MapUtils.log('display landmark ${m.id}: $e', tag: 'MapLandmarks');
        }
      }
    } finally {
      _drawingDisplayLandmarks = false;
    }
  }

  Future<void> _clearDisplayLandmarkAnnotations() async {
    if (pointAnnotationManager == null ||
        _displayLandmarkAnnotations.isEmpty) {
      _displayLandmarkAnnotations.clear();
      return;
    }
    for (final ann in _displayLandmarkAnnotations.values) {
      try {
        await pointAnnotationManager!.delete(ann);
      } catch (_) {}
    }
    _displayLandmarkAnnotations.clear();
  }

  String? findDisplayLandmarkIdByAnnotation(PointAnnotation annotation) {
    for (final e in _displayLandmarkAnnotations.entries) {
      if (e.value.id == annotation.id) return e.key;
    }
    return null;
  }

  MapLandmark? getDisplayLandmarkById(String id) => _displayLandmarkById[id];

  void showDisplayLandmarkInfoSheet(BuildContext context, MapLandmark m) {
    final color = LandmarkMarkerImages.colorFor(m.type);
    final icon = LandmarkMarkerImages.iconDataFor(m.type);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                m.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                m.type.labelAr,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (m.notes != null && m.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  m.notes!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    unawaited(flyToFlat(
                      latitude: m.latitude,
                      longitude: m.longitude,
                      zoom: 16.5,
                    ));
                  },
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  label: const Text('التركيز على الموقع'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void disposeDisplayLandmarks() {
    _displayLandmarkZoomDebounce?.cancel();
    _displayLandmarkZoomDebounce = null;
    _landmarksDisplaySub?.cancel();
    _landmarksDisplaySub = null;
    _displayLandmarkAnnotations.clear();
    _displayLandmarkById.clear();
  }
}
