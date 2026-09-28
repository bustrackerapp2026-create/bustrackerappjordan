import '../models/planned_route_stop_model.dart';
import '../models/route_point.dart';
import 'route_plan/route_polyline_projection.dart';

/// يربط محطة PlannedRoute بهندسة المسار دون إدخال معرفة المحطات
/// إلى الـgeometry primitive نفسه.
///
/// النتيجة مشتقة من:
/// - PlannedRouteStopModel.location
/// - List<RoutePoint>
///
/// و[RoutePolylineProjection.alongMeters] تمثل موضع المحطة على محور
/// المسار (stopAlongMeters) في runtime فقط.
class PlannedRouteStopProjection {
  PlannedRouteStopProjection._();

  static RoutePolylineProjection? project({
    required PlannedRouteStopModel stop,
    required List<RoutePoint> routePoints,
  }) {
    return RoutePolylineProjection.project(
      routePoints: routePoints,
      latitude: stop.location.latitude,
      longitude: stop.location.longitude,
    );
  }
}
