import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';

class DriverLocationData {
  final String id;
  final String fullName;
  final double latitude;
  final double longitude;
  final bool isOnline;
  final String? busNumber;
  final String? route;
  final String? phoneNumber;
  final DateTime? lastUpdated;

  const DriverLocationData({
    required this.id,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    this.busNumber,
    this.route,
    this.phoneNumber,
    this.lastUpdated,
  });

  factory DriverLocationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DriverLocationData(
      id: doc.id,
      fullName: data['fullName'] as String? ?? 'سائق',
      latitude: MapUtils.safeToDouble(data['currentLatitude']) ?? 0.0,
      longitude: MapUtils.safeToDouble(data['currentLongitude']) ?? 0.0,
      isOnline: data['isOnline'] as bool? ?? false,
      busNumber: data['busNumber'] as String?,
      route: data['route'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
}

mixin DriverManagerMixin<T extends StatefulWidget>
    on State<T>, MapCoreMixin<T> {
  final Map<String, PointAnnotation> driverAnnotations = {};
  final Map<String, DriverLocationData> driverDataById = {};
  final Map<String, Uint8List> _driverMarkerCache = {};
  StreamSubscription<QuerySnapshot>? _driversSubscription;

  DriverLocationData? getDriverData(String driverId) =>
      driverDataById[driverId];

  String? findDriverIdByAnnotation(PointAnnotation annotation) {
    for (final e in driverAnnotations.entries) {
      if (e.value.id == annotation.id) return e.key;
    }
    return null;
  }

  void listenToActiveDrivers() {
    _driversSubscription?.cancel();
    _driversSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('userType', isEqualTo: 'driver')
        .where('isVerified', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        _log('📦 تم استلام ${snapshot.docs.length} سائق نشط');
        _updateDriverMarkers(snapshot);
      },
      onError: (error) => _log('❌ خطأ في جلب السائقين: $error'),
    );
  }

  Future<void> _updateDriverMarkers(QuerySnapshot snapshot) async {
    if (pointAnnotationManager == null || !mounted) {
      return;
    }
    final newDriverIds = snapshot.docs.map((doc) => doc.id).toSet();
    final currentDriverIds = driverAnnotations.keys.toSet();
    final driversToRemove = currentDriverIds.difference(newDriverIds);

    for (final driverId in driversToRemove) {
      final annotation = driverAnnotations[driverId];
      if (annotation != null) {
        await pointAnnotationManager?.delete(annotation);
        driverAnnotations.remove(driverId);
      }
      driverDataById.remove(driverId);
    }

    for (final doc in snapshot.docs) {
      if (!mounted) return;
      final driver = DriverLocationData.fromFirestore(doc);
      driverDataById[driver.id] = driver;
      if (driver.latitude == 0.0 || driver.longitude == 0.0) {
        continue;
      }
      await _createOrUpdateMarker(
        driverId: driver.id,
        lat: driver.latitude,
        lng: driver.longitude,
        name: driver.fullName,
        isOnline: driver.isOnline,
      );
    }
  }

  Future<void> _createOrUpdateMarker({
    required String driverId,
    required double lat,
    required double lng,
    required String name,
    required bool isOnline,
  }) async {
    if (pointAnnotationManager == null || !mounted) {
      return;
    }
    final point = Point(coordinates: Position(lng, lat));
    if (driverAnnotations.containsKey(driverId)) {
      final annotation = driverAnnotations[driverId]!;
      annotation.geometry = point;
      await pointAnnotationManager?.update(annotation);
      return;
    }
    final markerBytes =
        await _createDriverMarkerImage(name: name, isOnline: isOnline);
    if (markerBytes == null || !mounted) {
      return;
    }
    final options = PointAnnotationOptions(
      geometry: point,
      image: markerBytes,
      iconSize: 1.0,
      iconAnchor: IconAnchor.BOTTOM,
    );
    final annotation = await pointAnnotationManager?.create(options);
    if (annotation != null && mounted) {
      driverAnnotations[driverId] = annotation;
    }
  }

  Future<Uint8List?> _createDriverMarkerImage({
    required String name,
    required bool isOnline,
  }) async {
    final cacheKey = '${name}_${isOnline ? '1' : '0'}';
    if (_driverMarkerCache.containsKey(cacheKey)) {
      return _driverMarkerCache[cacheKey];
    }
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 80.0;
      const center = Offset(size / 2, size / 2);
      canvas.drawColor(Colors.transparent, BlendMode.clear);

      final glowColor = isOnline ? Colors.green : Colors.grey;
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawCircle(center, 22, glowPaint);

      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 16, outerPaint);

      final innerPaint = Paint()
        ..color = isOnline ? Colors.green.shade600 : Colors.grey.shade600
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12, innerPaint);

      final busPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final busPath = Path();
      const centerX = size / 2;
      const centerY = size / 2;

      busPath.addRect(
        Rect.fromCenter(
          center: const Offset(centerX, centerY + 2),
          width: 14,
          height: 10,
        ),
      );
      busPath.addOval(
        Rect.fromCenter(
          center: const Offset(centerX - 5, centerY + 8),
          width: 4,
          height: 4,
        ),
      );
      busPath.addOval(
        Rect.fromCenter(
          center: const Offset(centerX + 5, centerY + 8),
          width: 4,
          height: 4,
        ),
      );
      canvas.drawPath(busPath, busPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: size);
      textPainter.paint(
        canvas,
        Offset((size - textPainter.width) / 2, size - 14),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final bytes = byteData!.buffer.asUint8List();

      _driverMarkerCache[cacheKey] = bytes;
      return bytes;
    } catch (e) {
      _log('⚠️ خطأ في رسم علامة السائق: $e');
      return null;
    }
  }

  void disposeDrivers() {
    _driversSubscription?.cancel();
    driverAnnotations.clear();
    driverDataById.clear();
    _driverMarkerCache.clear();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('📌 [AdminMap] $message');
    }
  }
}
