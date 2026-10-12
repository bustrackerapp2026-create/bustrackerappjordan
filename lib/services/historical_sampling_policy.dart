import 'package:geolocator/geolocator.dart';

/// سياسة حداثة GPS للتسجيل التاريخي.
///
/// لا تعتمد على وقت وصول الـPosition إلى الـcallback؛ تعتمد على
/// [Position.timestamp] حتى لا يُعامل الموقع cached القديم كموقع حي.
class HistoricalSamplingPolicy {
  HistoricalSamplingPolicy._();

  /// أثناء DriverTrip لا نقبل Historical TripPing أقدم من هذه المدة.
  static const Duration maxPositionAge = Duration(seconds: 45);

  static bool isFresh(
    Position position, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final age = reference.difference(position.timestamp);

    return age >= Duration.zero && age <= maxPositionAge;
  }
}
