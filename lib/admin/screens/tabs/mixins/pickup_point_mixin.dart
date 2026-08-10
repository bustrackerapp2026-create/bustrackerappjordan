import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/pickup/pickup_marker_helper.dart';
import '../../../../models/pickup_point_model.dart';

/// مكسين نقاط التجمع لخريطة الأدمن — يعرض كل النقاط المعتمدة.
mixin PickupPointMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, Uint8List> _pickupMarkerCache = {};
  StreamSubscription<QuerySnapshot>? _pickupSubscription;
  QuerySnapshot? _pendingSnapshot;
  bool _isUpdating = false;
  bool _resyncScheduled = false;

  Map<String, PointAnnotation> get pickupAnnotations => _pickupAnnotations;

  bool _isApprovedDoc(Map<String, dynamic> data) {
    final status = data['status']?.toString();
    final isApprovedFlag = data['isApproved'] == true;

    if (status == 'rejected') return false;
    if (status == 'approved' || isApprovedFlag) return true;
    if (status == 'pending') return false;

    if (status == null || status.isEmpty) {
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
        if (data.containsKey('isApproved') && data['isApproved'] != true) {
          return false;
        }
        return true;
      }
    }
    return false;
  }

  void listenToPickupPoints() {
    _pickupSubscription?.cancel();
    _pickupSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .snapshots()
        .listen(
      (snapshot) {
        MapUtils.log(
          '📦 نقاط التجمع: ${snapshot.docs.length} مستند',
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
    }
  }

  Future<Uint8List?> _createPickupMarkerImage({
    required String name,
    required String pointType,
    required int count,
  }) async {
    final cacheKey = 'pickup_${name.hashCode}_${count}_$pointType';
    if (_pickupMarkerCache.containsKey(cacheKey)) {
      return _pickupMarkerCache[cacheKey];
    }

    final bytes = await PickupMarkerHelper.createMarkerBytes(
      name: name,
      pointType: pointType,
      confirmationCount: count,
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
    _pickupSubscription?.cancel();
    _pendingSnapshot = null;
    _pickupAnnotations.clear();
    _pickupMarkerCache.clear();
  }
}
