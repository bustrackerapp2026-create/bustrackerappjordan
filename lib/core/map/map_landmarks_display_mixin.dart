import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../models/map_landmark.dart';
import '../../services/map_landmark_service.dart';
import 'landmark_marker_images.dart';
import 'map_core.dart';
import 'map_utils.dart';

/// عرض المعالم المعتمدة فقط (للراكب/السائق) مع سلوك Google Maps:
/// - حجم أيقونة/خط قريب من Google POI
/// - ظهور/اختفاء حسب أهمية النوع مع الزوم (LOD)
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

  /// كاش أيقونات حسب النوع لتقليل إعادة الرسم عند تغيّر LOD.
  final Map<MapLandmarkType, Uint8List> _displayIconBytes = {};

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

  /// يُستدعى من مستمع الكاميرا لتحديث الحجم/الاسم/الظهور حسب الزوم.
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

      // إذا تغيّر مستوى التفاصيل (ظهور/اختفاء أنواع) أعد رسم المجموعة الظاهرة
      if (prev < 0 || _lodSetChanged(prev, zoom)) {
        await _syncDisplayLandmarksForZoom(zoom);
      } else {
        await _updateDisplayLandmarkStyle(zoom);
      }
    } catch (e) {
      MapUtils.log('display landmark zoom: $e', tag: 'MapLandmarks');
    }
  }

  /// هل تغيّرت مجموعة الأنواع الظاهرة بين زومين؟
  bool _lodSetChanged(double a, double b) {
    for (final t in MapLandmarkType.values) {
      if (LandmarkMarkerImages.isVisibleAtZoom(t, a) !=
          LandmarkMarkerImages.isVisibleAtZoom(t, b)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensureDisplayIconBytes(Iterable<MapLandmarkType> types) async {
    for (final t in types) {
      if (!_displayIconBytes.containsKey(t)) {
        _displayIconBytes[t] = await LandmarkMarkerImages.bytesFor(t);
      }
    }
  }

  /// مزامنة العلامات الظاهرة مع الزوم الحالي (إضافة/حذف حسب الأهمية).
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

      // حذف ما لم يعد ظاهراً
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

      // إنشاء الناقص
      final missing = visible
          .where((m) => !_displayLandmarkAnnotations.containsKey(m.id))
          .toList();
      if (missing.isNotEmpty) {
        await _ensureDisplayIconBytes(missing.map((m) => m.type).toSet());
        final iconSize = LandmarkMarkerImages.iconSizeForZoom(zoom);
        final textOffset = LandmarkMarkerImages.textOffsetForZoom(zoom);

        for (final m in missing) {
          final bytes = _displayIconBytes[m.type];
          if (bytes == null) continue;
          final name = m.name.trim();
          final showLabel =
              LandmarkMarkerImages.showLabelAtZoom(m.type, zoom) &&
                  name.isNotEmpty;
          final textSize = showLabel
              ? LandmarkMarkerImages.textSizeForZoom(zoom)
              : 0.0;
          try {
            final ann = await pointAnnotationManager!.create(
              PointAnnotationOptions(
                geometry: Point(
                  coordinates: Position(m.longitude, m.latitude),
                ),
                image: bytes,
                iconSize: iconSize,
                iconAnchor: IconAnchor.CENTER,
                textField: showLabel ? name : null,
                textSize: textSize,
                textColor: 0xFF212121,
                textHaloColor: 0xFFFFFFFF,
                textHaloWidth: 1.15,
                textAnchor: TextAnchor.TOP,
                textOffset: textOffset,
                textMaxWidth: 9,
                textJustify: TextJustify.CENTER,
              ),
            );
            _displayLandmarkAnnotations[m.id] = ann;
          } catch (e) {
            MapUtils.log('display landmark ${m.id}: $e', tag: 'MapLandmarks');
          }
        }
      }

      // تحديث الحجم/الاسم للظاهر
      await _updateDisplayLandmarkStyle(zoom);
    } finally {
      _drawingDisplayLandmarks = false;
    }
  }

  Future<void> _updateDisplayLandmarkStyle(double zoom) async {
    if (_updatingDisplayLandmarkScale || pointAnnotationManager == null) return;
    _updatingDisplayLandmarkScale = true;
    try {
      final iconSize = LandmarkMarkerImages.iconSizeForZoom(zoom);
      final textOffset = LandmarkMarkerImages.textOffsetForZoom(zoom);

      for (final entry in _displayLandmarkAnnotations.entries) {
        final m = _displayLandmarkById[entry.key];
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
          ann.textColor = 0xFF212121;
          ann.textHaloColor = 0xFFFFFFFF;
          ann.textHaloWidth = 1.15;
          ann.textAnchor = TextAnchor.TOP;
          ann.textJustify = TextJustify.CENTER;
          ann.textMaxWidth = 9;
        } else {
          ann.textField = '';
          ann.textSize = 0;
        }

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

      await _ensureDisplayIconBytes(visible.map((m) => m.type).toSet());
      if (pointAnnotationManager == null) return;

      final iconSize = LandmarkMarkerImages.iconSizeForZoom(zoom);
      final textOffset = LandmarkMarkerImages.textOffsetForZoom(zoom);

      for (final m in visible) {
        final bytes = _displayIconBytes[m.type];
        if (bytes == null) continue;
        final name = m.name.trim();
        final showLabel =
            LandmarkMarkerImages.showLabelAtZoom(m.type, zoom) &&
                name.isNotEmpty;
        final textSize =
            showLabel ? LandmarkMarkerImages.textSizeForZoom(zoom) : 0.0;
        try {
          final ann = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(m.longitude, m.latitude),
              ),
              image: bytes,
              iconSize: iconSize,
              iconAnchor: IconAnchor.CENTER,
              textField: showLabel ? name : null,
              textSize: textSize,
              textColor: 0xFF212121,
              textHaloColor: 0xFFFFFFFF,
              textHaloWidth: 1.15,
              textAnchor: TextAnchor.TOP,
              textOffset: textOffset,
              textMaxWidth: 9,
              textJustify: TextJustify.CENTER,
            ),
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

  /// بطاقة معلومات بسيطة عند الضغط على معلم (عرض فقط).
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
    _displayIconBytes.clear();
  }
}
