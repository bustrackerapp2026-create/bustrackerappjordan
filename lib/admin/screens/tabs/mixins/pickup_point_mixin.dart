import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/pickup/pickup_marker_helper.dart';
import '../../../../models/pickup_point_model.dart';

/// مكسين إدارة نقاط التجمع لخريطة الأدمن (نفس الشكل المستخدم في السائق والراكب).
mixin PickupPointMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, Uint8List> _pickupMarkerCache = {};
  StreamSubscription<QuerySnapshot>? _pickupSubscription;

  Map<String, PointAnnotation> get pickupAnnotations => _pickupAnnotations;

  void listenToPickupPoints() {
    _pickupSubscription?.cancel();
    _pickupSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen(
      (snapshot) {
        MapUtils.log(
          '📦 تم استلام ${snapshot.docs.length} نقطة تجمع موثقة',
          tag: 'PickupMixin',
        );
        _updatePickupMarkers(snapshot);
      },
      onError: (error) => MapUtils.log(
        '❌ خطأ في جلب نقاط التجمع: $error',
        tag: 'PickupMixin',
      ),
    );
  }

  Future<void> _updatePickupMarkers(QuerySnapshot snapshot) async {
    if (!mounted) return;
    if (pointAnnotationManager == null) {
      // الخريطة قد لا تكون جاهزة بعد — ننتظر ثم نعيد المحاولة
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || pointAnnotationManager == null) return;
    }

    final newPickupIds = snapshot.docs.map((doc) => doc.id).toSet();
    final currentPickupIds = _pickupAnnotations.keys.toSet();
    final toRemove = currentPickupIds.difference(newPickupIds);

    for (final id in toRemove) {
      final annotation = _pickupAnnotations[id];
      if (annotation != null) {
        try {
          await pointAnnotationManager?.delete(annotation);
        } catch (_) {}
        _pickupAnnotations.remove(id);
        _pickupMarkerCache.remove(id);
      }
    }

    for (final doc in snapshot.docs) {
      if (!mounted) return;
      try {
        final point = PickupPointModel.fromFirestore(doc);
        if (point.latitude == 0.0 && point.longitude == 0.0) continue;
        await _createOrUpdatePickupMarker(
          pickupId: point.id,
          lat: point.latitude,
          lng: point.longitude,
          name: point.name,
          pointType: point.pointType,
          confirmationCount: point.confirmationCount,
        );
      } catch (e) {
        MapUtils.log(
          '⚠️ خطأ في معالجة نقطة ${doc.id}: $e',
          tag: 'PickupMixin',
        );
      }
    }

    MapUtils.log(
      '✅ تم تحديث نقاط التجمع، يوجد ${_pickupAnnotations.length} نقطة',
      tag: 'PickupMixin',
    );
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
    MapUtils.log('📍 تم الضغط على نقطة تجمع: $pickupId', tag: 'PickupMixin');
  }

  void disposePickupPoints() {
    _pickupSubscription?.cancel();
    _pickupAnnotations.clear();
    _pickupMarkerCache.clear();
  }
}
