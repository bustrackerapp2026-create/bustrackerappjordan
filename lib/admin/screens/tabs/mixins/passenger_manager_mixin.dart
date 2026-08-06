import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart'; // ✅ إضافة الاستيراد

mixin PassengerManagerMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final Map<String, PointAnnotation> _passengerAnnotations = {};
  final Map<String, Uint8List> _passengerMarkerCache = {};
  StreamSubscription<QuerySnapshot>? _passengersSubscription;
  bool showPassengers = true;

  void listenToActivePassengers() {
    _passengersSubscription?.cancel();
    _passengersSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('userType', isEqualTo: 'passenger')
        .snapshots()
        .listen(
      (snapshot) {
        _log('📦 تم استلام ${snapshot.docs.length} راكب من Firestore');
        _updatePassengerMarkers(snapshot);
      },
      onError: (error) => _log('❌ خطأ في جلب الركاب: $error'),
    );
  }

  Future<void> _updatePassengerMarkers(QuerySnapshot snapshot) async {
    if (!showPassengers || pointAnnotationManager == null || !mounted) {
      return;
    }

    final now = DateTime.now();
    final newPassengerIds = <String>{};
    final validPassengers = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      // ✅ استخدام MapUtils.safeToDouble
      final lat = MapUtils.safeToDouble(data['currentLatitude']);
      final lng = MapUtils.safeToDouble(data['currentLongitude']);

      if (lat == null || lng == null) {
        continue;
      }

      final lastUpdate = data['locationUpdatedAt'] as Timestamp?;
      if (lastUpdate != null) {
        final diff = now.difference(lastUpdate.toDate()).inMinutes;
        if (diff > 5) {
          continue;
        }
      } else {
        continue;
      }

      newPassengerIds.add(id);
      validPassengers.add({'id': id, ...data});
    }

    final currentPassengerIds = _passengerAnnotations.keys.toSet();
    final toRemove = currentPassengerIds.difference(newPassengerIds);

    for (final id in toRemove) {
      final annotation = _passengerAnnotations[id];
      if (annotation != null) {
        await pointAnnotationManager?.delete(annotation);
        _passengerAnnotations.remove(id);
        _passengerMarkerCache.remove(id);
      }
    }

    for (final passenger in validPassengers) {
      final id = passenger['id'] as String;
      final lat = MapUtils.safeToDouble(passenger['currentLatitude'])!;
      final lng = MapUtils.safeToDouble(passenger['currentLongitude'])!;
      await _createOrUpdatePassengerMarker(passengerId: id, lat: lat, lng: lng);
    }

    _log('✅ تم تحديث الركاب، يوجد ${_passengerAnnotations.length} راكب نشط');
  }

  // ... باقي الدوال كما هي (لم تتغير)
  Future<void> _createOrUpdatePassengerMarker({
    required String passengerId,
    required double lat,
    required double lng,
  }) async {
    if (pointAnnotationManager == null || !mounted) {
      return;
    }
    final point = Point(coordinates: Position(lng, lat));
    if (_passengerAnnotations.containsKey(passengerId)) {
      final annotation = _passengerAnnotations[passengerId]!;
      annotation.geometry = point;
      await pointAnnotationManager?.update(annotation);
      return;
    }
    final markerBytes = await _createPassengerMarkerImage();
    if (markerBytes == null || !mounted) {
      return;
    }
    final options = PointAnnotationOptions(
      geometry: point,
      image: markerBytes,
      iconSize: 1.0,
      iconAnchor: IconAnchor.CENTER,
    );
    final annotation = await pointAnnotationManager?.create(options);
    if (annotation != null) {
      _passengerAnnotations[passengerId] = annotation;
    }
  }

  Future<Uint8List?> _createPassengerMarkerImage() async {
    const cacheKey = 'passenger_marker';
    if (_passengerMarkerCache.containsKey(cacheKey)) {
      return _passengerMarkerCache[cacheKey];
    }
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 50.0;
      const center = Offset(size / 2, size / 2);
      canvas.drawColor(Colors.transparent, BlendMode.clear);

      final glowPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawCircle(center, 18, glowPaint);

      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12, outerPaint);

      final innerPaint = Paint()
        ..color = Colors.blue.shade600
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 9, innerPaint);

      final personPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(center.dx, center.dy - 2), 3.5, personPaint);

      final bodyPath = Path();
      bodyPath.addOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 5),
          width: 9,
          height: 7,
        ),
      );
      canvas.drawPath(bodyPath, personPaint);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      _passengerMarkerCache[cacheKey] = bytes;
      return bytes;
    } catch (e) {
      _log('⚠️ خطأ في رسم علامة الراكب: $e');
      return null;
    }
  }

  void togglePassengersVisibility() {
    if (!mounted) {
      return;
    }
    setState(() {
      showPassengers = !showPassengers;
    });
    if (showPassengers) {
      listenToActivePassengers();
      _log('👥 إظهار الركاب');
    } else {
      _clearPassengerMarkers();
      _log('👥 إخفاء الركاب');
    }
  }

  Future<void> _clearPassengerMarkers() async {
    if (pointAnnotationManager == null) {
      return;
    }
    for (final annotation in _passengerAnnotations.values) {
      await pointAnnotationManager?.delete(annotation);
    }
    _passengerAnnotations.clear();
    _passengerMarkerCache.clear();
  }

  void disposePassengers() {
    _passengersSubscription?.cancel();
    _passengerAnnotations.clear();
    _passengerMarkerCache.clear();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('📌 [AdminMap] $message');
    }
  }
}
