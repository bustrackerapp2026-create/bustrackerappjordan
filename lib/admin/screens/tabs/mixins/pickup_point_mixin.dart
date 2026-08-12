import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/pickup_label_scale_provider.dart';
import '../../../../core/pickup/pickup_marker_helper.dart';
import '../../../../models/pickup_point_model.dart';

mixin PickupPointMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, Uint8List> _pickupMarkerCache = {};
  final Map<String, String> _markerVisualKey = {};
  StreamSubscription<QuerySnapshot>? _pickupSubscription;
  QuerySnapshot? _pendingSnapshot;
  bool _isUpdating = false;
  bool _resyncScheduled = false;
  PickupLabelScaleProvider? _labelScaleProvider;
  double _appliedLabelScale = 1.0;

  Map<String, PointAnnotation> get pickupAnnotations => _pickupAnnotations;

  bool _isApprovedDoc(Map<String, dynamic> data) {
    final status = data['status']?.toString().trim().toLowerCase();
    return status == 'approved';
  }

  void _onLabelScaleChanged() {
    if (!mounted) return;
    final next = PickupLabelScaleProvider.currentScale;
    if ((next - _appliedLabelScale).abs() < 0.01) return;
    _appliedLabelScale = next;
    PickupMarkerHelper.clearCache();
    _pickupMarkerCache.clear();
    _markerVisualKey.clear();
    _forceRedraw();
  }

  Future<void> _forceRedraw() async {
    final ids = _pickupAnnotations.keys.toList();
    for (final id in ids) {
      final annotation = _pickupAnnotations.remove(id);
      if (annotation != null) {
        try {
          await pointAnnotationManager?.delete(annotation);
        } catch (_) {}
      }
    }
    if (mounted) _updatePickupMarkers();
  }

  void listenToPickupPoints() {
    _pickupSubscription?.cancel();

    try {
      _labelScaleProvider?.removeListener(_onLabelScaleChanged);
      _labelScaleProvider = context.read<PickupLabelScaleProvider>();
      _appliedLabelScale = _labelScaleProvider!.scale;
      _labelScaleProvider!.addListener(_onLabelScaleChanged);
    } catch (_) {
      _appliedLabelScale = PickupLabelScaleProvider.currentScale;
    }

    _pickupSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen(
      (snapshot) {
        MapUtils.log(
          '📦 نقاط معتمدة: ${snapshot.docs.length}',
          tag: 'AdminPickup',
        );
        _pendingSnapshot = snapshot;
        _updatePickupMarkers();
      },
      onError: (error) => MapUtils.log(
        '❌ خطأ في جلب نقاط التجمع: $error',
        tag: 'AdminPickup',
      ),
    );
  }

  void _scheduleResync() {
    if (_resyncScheduled) return;
    _resyncScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      _resyncScheduled = false;
      if (mounted) _updatePickupMarkers();
    });
  }

  Future<void> _updatePickupMarkers() async {
    if (!mounted || _isUpdating) return;
    final snapshot = _pendingSnapshot;
    if (snapshot == null) return;

    if (pointAnnotationManager == null) {
      _scheduleResync();
      return;
    }

    _isUpdating = true;
    try {
      final approved = <PickupPointModel>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (!_isApprovedDoc(data)) continue;
          final point = PickupPointModel.fromFirestore(doc);
          if (point.latitude == 0.0 && point.longitude == 0.0) continue;
          approved.add(point);
        } catch (e) {
          MapUtils.log('⚠️ تخطي ${doc.id}: $e', tag: 'AdminPickup');
        }
      }

      final newIds = approved.map((p) => p.id).toSet();
      final toRemove = _pickupAnnotations.keys.toSet().difference(newIds);

      for (final id in toRemove) {
        final annotation = _pickupAnnotations.remove(id);
        if (annotation != null) {
          try {
            await pointAnnotationManager?.delete(annotation);
          } catch (_) {}
          _pickupMarkerCache.remove(id);
          _markerVisualKey.remove(id);
        }
      }

      for (final point in approved) {
        if (!mounted) return;
        await _createOrUpdatePickupMarker(
          pickupId: point.id,
          lat: point.latitude,
          lng: point.longitude,
          name: point.name,
          pointType: point.pointType,
          confirmationCount: point.confirmationCount,
        );
      }

      MapUtils.log(
        '✅ معروض ${_pickupAnnotations.length} نقطة معتمدة',
        tag: 'AdminPickup',
      );
    } finally {
      _isUpdating = false;
      if (_pendingSnapshot != snapshot && mounted) {
        _scheduleResync();
      }
    }
  }

  Future<void> _createOrUpdatePickupMarker({
    required String pickupId,
    required double lat,
    required double lng,
    required String name,
    required String pointType,
    required int confirmationCount,
  }) async {
    if (pointAnnotationManager == null || !mounted) return;

    final scale = PickupLabelScaleProvider.currentScale;
    final visualKey =
        '${pointType}_${name.hashCode}_s${(scale * 100).round()}';

    if (_pickupAnnotations.containsKey(pickupId) &&
        _markerVisualKey[pickupId] == visualKey) {
      return;
    }

    if (_pickupAnnotations.containsKey(pickupId)) {
      final annotation = _pickupAnnotations.remove(pickupId)!;
      try {
        await pointAnnotationManager?.delete(annotation);
      } catch (_) {}
    }

    final markerBytes = await _createPickupMarkerImage(
      name: name,
      pointType: pointType,
      count: confirmationCount,
      scale: scale,
    );
    if (markerBytes == null || !mounted) return;

    final options = PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      image: markerBytes,
      iconSize: 1.05,
      iconAnchor: IconAnchor.BOTTOM,
    );

    final annotation = await pointAnnotationManager?.create(options);
    if (annotation != null) {
      _pickupAnnotations[pickupId] = annotation;
      _markerVisualKey[pickupId] = visualKey;
    }
  }

  Future<Uint8List?> _createPickupMarkerImage({
    required String name,
    required String pointType,
    required int count,
    required double scale,
  }) async {
    final cacheKey =
        'pickup_${name.hashCode}_${count}_${pointType}_s${(scale * 100).round()}';
    if (_pickupMarkerCache.containsKey(cacheKey)) {
      return _pickupMarkerCache[cacheKey];
    }

    final bytes = await PickupMarkerHelper.createMarkerBytes(
      name: name,
      pointType: pointType,
      confirmationCount: count,
      textScale: scale,
    );
    if (bytes != null) {
      _pickupMarkerCache[cacheKey] = bytes;
    }
    return bytes;
  }

  void handlePickupTap(String pickupId) {
    MapUtils.log('📍 تم الضغط على نقطة تجمع: $pickupId', tag: 'AdminPickup');
  }

  void disposePickupPoints() {
    _labelScaleProvider?.removeListener(_onLabelScaleChanged);
    _labelScaleProvider = null;
    _pickupSubscription?.cancel();
    _pendingSnapshot = null;
    _pickupAnnotations.clear();
    _pickupMarkerCache.clear();
    _markerVisualKey.clear();
  }
}
