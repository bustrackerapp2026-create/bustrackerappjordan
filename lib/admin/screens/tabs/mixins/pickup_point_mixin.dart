import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../models/pickup_point_model.dart';

/// مكسين إدارة نقاط التجمع لخريطة الأدمن
mixin PickupPointMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  // ─── المتغيرات الخاصة ────────────────────────────────────────────
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, Uint8List> _pickupMarkerCache = {};
  StreamSubscription<QuerySnapshot>? _pickupSubscription;

  // ─── Getter عام للوصول إلى العلامات ──────────────────────────────
  Map<String, PointAnnotation> get pickupAnnotations => _pickupAnnotations;

  // ─── الاستماع لنقاط التجمع ──────────────────────────────────────
  void listenToPickupPoints() {
    _pickupSubscription?.cancel();
    _pickupSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen(
      (snapshot) {
        MapUtils.log('📦 تم استلام ${snapshot.docs.length} نقطة تجمع موثقة',
            tag: 'PickupMixin');
        _updatePickupMarkers(snapshot);
      },
      onError: (error) =>
          MapUtils.log('❌ خطأ في جلب نقاط التجمع: $error', tag: 'PickupMixin'),
    );
  }

  Future<void> _updatePickupMarkers(QuerySnapshot snapshot) async {
    if (pointAnnotationManager == null || !mounted) return;

    final newPickupIds = snapshot.docs.map((doc) => doc.id).toSet();
    final currentPickupIds = _pickupAnnotations.keys.toSet();
    final toRemove = currentPickupIds.difference(newPickupIds);

    for (final id in toRemove) {
      final annotation = _pickupAnnotations[id];
      if (annotation != null) {
        await pointAnnotationManager?.delete(annotation);
        _pickupAnnotations.remove(id);
        _pickupMarkerCache.remove(id);
      }
    }

    for (final doc in snapshot.docs) {
      try {
        final point = PickupPointModel.fromFirestore(doc);
        if (point.latitude == 0.0 || point.longitude == 0.0) continue;
        await _createOrUpdatePickupMarker(
          pickupId: point.id,
          lat: point.latitude,
          lng: point.longitude,
          name: point.name,
          confirmationCount: point.confirmationCount,
        );
      } catch (e) {
        MapUtils.log('⚠️ خطأ في معالجة نقطة ${doc.id}: $e', tag: 'PickupMixin');
      }
    }

    MapUtils.log(
        '✅ تم تحديث نقاط التجمع، يوجد ${_pickupAnnotations.length} نقطة',
        tag: 'PickupMixin');
  }

  Future<void> _createOrUpdatePickupMarker({
    required String pickupId,
    required double lat,
    required double lng,
    required String name,
    required int confirmationCount,
  }) async {
    if (pointAnnotationManager == null || !mounted) return;

    final point = Point(coordinates: Position(lng, lat));

    if (_pickupAnnotations.containsKey(pickupId)) {
      final annotation = _pickupAnnotations[pickupId]!;
      annotation.geometry = point;
      await pointAnnotationManager?.update(annotation);
      return;
    }

    final markerBytes =
        await _createPickupMarkerImage(name: name, count: confirmationCount);
    if (markerBytes == null || !mounted) return;

    final options = PointAnnotationOptions(
      geometry: point,
      image: markerBytes,
      iconSize: 1.0,
      iconAnchor: IconAnchor.BOTTOM,
    );

    final annotation = await pointAnnotationManager?.create(options);
    if (annotation != null) {
      _pickupAnnotations[pickupId] = annotation;
    }
  }

  Future<Uint8List?> _createPickupMarkerImage({
    required String name,
    required int count,
  }) async {
    final cacheKey = 'pickup_${name.hashCode}_$count';
    if (_pickupMarkerCache.containsKey(cacheKey)) {
      return _pickupMarkerCache[cacheKey];
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 70.0;
      const center = Offset(size / 2, size / 2);

      canvas.drawColor(Colors.transparent, BlendMode.clear);

      final glowPaint = Paint()
        ..color = Colors.orange.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
      canvas.drawCircle(center, 22, glowPaint);

      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 16, outerPaint);

      final innerPaint = Paint()
        ..color = Colors.orange.shade600
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12, innerPaint);

      final locationPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final locationPath = Path();
      final locCenter = Offset(center.dx, center.dy - 2);
      locationPath
          .addOval(Rect.fromCenter(center: locCenter, width: 6, height: 6));
      locationPath.moveTo(locCenter.dx, locCenter.dy + 3);
      locationPath.lineTo(locCenter.dx - 4, locCenter.dy + 10);
      locationPath.lineTo(locCenter.dx + 4, locCenter.dy + 10);
      locationPath.close();
      canvas.drawPath(locationPath, locationPaint);

      final countPainter = TextPainter(
        text: TextSpan(
            text: '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      countPainter.layout();
      countPainter.paint(canvas, Offset(center.dx + 10, center.dy - 6));

      final textPainter = TextPainter(
        text: TextSpan(
            text: name,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: size);
      textPainter.paint(
          canvas, Offset((size - textPainter.width) / 2, size - 12));

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      _pickupMarkerCache[cacheKey] = bytes;
      return bytes;
    } catch (e) {
      MapUtils.log('⚠️ خطأ في رسم علامة نقطة التجمع: $e', tag: 'PickupMixin');
      return null;
    }
  }

  void handlePickupTap(String pickupId) {
    MapUtils.log('📍 تم الضغط على نقطة تجمع: $pickupId', tag: 'PickupMixin');
    // سيتم تطوير عرض BottomSheet لاحقاً
  }

  void disposePickupPoints() {
    _pickupSubscription?.cancel();
    _pickupAnnotations.clear();
    _pickupMarkerCache.clear();
  }
}
