import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات ممثل لنقطة المسار بنوع صريح ومرونة عالية
class RoutePoint {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double? speed;
  final double? heading;
  final double? accuracy;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.speed,
    this.heading,
    this.accuracy,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    DateTime? parsedTime;
    if (map['timestamp'] is Timestamp) {
      parsedTime = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is DateTime) {
      parsedTime = map['timestamp'] as DateTime;
    }

    return RoutePoint(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: parsedTime,
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
    );
  }

  /// ✅ محول دفاعي يتعامل مع التنسيق القديم [[lng, lat]] أو التنسيق الحديث Map
  static RoutePoint? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return RoutePoint.fromMap(raw);
    } else if (raw is List && raw.length >= 2) {
      final lng = (raw[0] as num?)?.toDouble();
      final lat = (raw[1] as num?)?.toDouble();
      if (lng != null && lat != null) {
        return RoutePoint(latitude: lat, longitude: lng);
      }
    }
    return null;
  }
}
