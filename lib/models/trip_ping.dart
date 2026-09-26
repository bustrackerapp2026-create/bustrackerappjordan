import 'package:cloud_firestore/cloud_firestore.dart';

/// لقطة GPS تاريخية واحدة مرتبطة برحلة تشغيلية.
class TripPing {
  final String tripId;
  final String routeId;
  final String direction;
  final GeoPoint location;
  final double? speed;
  final double? heading;
  final DateTime timestamp;

  const TripPing({
    required this.tripId,
    required this.routeId,
    required this.direction,
    required this.location,
    required this.timestamp,
    this.speed,
    this.heading,
  });

  bool get isValid {
    final lat = location.latitude;
    final lng = location.longitude;
    final normalizedDirection = direction.trim().toLowerCase();

    return tripId.trim().isNotEmpty &&
        routeId.trim().isNotEmpty &&
        (normalizedDirection == 'outbound' ||
            normalizedDirection == 'return') &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        (speed == null || (speed!.isFinite && speed! >= 0)) &&
        (heading == null || (heading!.isFinite && heading! >= 0));
  }

  Map<String, dynamic> toFirestoreMap() {
    if (!isValid) {
      throw const FormatException('TripPing data is invalid.');
    }

    return {
      'tripId': tripId.trim(),
      'routeId': routeId.trim(),
      'direction': direction.trim().toLowerCase(),
      'location': location,
      'speed': speed,
      'heading': heading,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory TripPing.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    final timestamp = rawTimestamp is Timestamp
        ? rawTimestamp.toDate()
        : rawTimestamp is DateTime
            ? rawTimestamp
            : DateTime.fromMillisecondsSinceEpoch(0);

    final rawLocation = map['location'];
    final location = rawLocation is GeoPoint
        ? rawLocation
        : const GeoPoint(0, 0);

    return TripPing(
      tripId: map['tripId']?.toString() ?? '',
      routeId: map['routeId']?.toString() ?? '',
      direction: map['direction']?.toString() ?? '',
      location: location,
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      timestamp: timestamp,
    );
  }
}
