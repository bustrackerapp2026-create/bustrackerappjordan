import '../models/planned_route.dart';
import '../models/route_point.dart';

/// يحسم نقطة بداية المسار التشغيلي وفق ترتيب PlannedRoute.points.
class RouteStartResolver {
  RouteStartResolver._();

  static RoutePoint? resolve(PlannedRoute route) {
    if (route.points.isEmpty) return null;
    return route.points.first;
  }
}
