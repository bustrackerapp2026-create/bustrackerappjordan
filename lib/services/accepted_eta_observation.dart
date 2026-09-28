import 'route_progress_calculator.dart';

/// Accepted GPS observation paired with the accepted RouteProgress projection.
///
/// This is an integration-layer snapshot only. It carries the route-axis
/// position accepted by [RouteProgressTracker] together with the speed and
/// source observation timestamp from the same accepted GPS sample.
///
/// A rejected GPS sample must not replace the current observation.
class AcceptedEtaObservation {
  final RouteProgressProjection acceptedRouteProgress;
  final double speedMps;
  final DateTime observedAt;

  const AcceptedEtaObservation({
    required this.acceptedRouteProgress,
    required this.speedMps,
    required this.observedAt,
  });
}
