import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/arabic_search.dart';
import '../models/planned_route.dart';
import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_plan/route_plan_mapbox.dart';

/// خدمة مسارات الخطوط المشتركة (ذهاب/إياب).
class RoutePlanService {
  RoutePlanService._();
  static final RoutePlanService instance = RoutePlanService._();
  factory RoutePlanService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RoutePlanMapbox _mapbox = RoutePlanMapbox.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('plannedRoutes');

  static const int minPointsToSave = 8;
  static const int maxPointsToStore = RoutePlanGeometry.maxPointsToStore;
  static const double pointSnapRadiusM = RoutePlanMapbox.pointSnapRadiusM;

  Future<RoutePoint> snapPointToRoad(RoutePoint point) =>
      _mapbox.snapPointToRoad(point);

  Future<List<RoutePoint>> getDrivingPath({
    required RoutePoint from,
    required RoutePoint to,
    bool snapEndpoints = true,
    bool attachControlEndpoints = true,
    int? perfTapId,
    int? perfSegmentIndex,
  }) =>
      _mapbox.getDrivingPath(
        from: from,
        to: to,
        snapEndpoints: snapEndpoints,
        attachControlEndpoints: attachControlEndpoints,
        perfTapId: perfTapId,
        perfSegmentIndex: perfSegmentIndex,
      );

  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints, {
    bool snapWaypoints = true,
    bool preserveWaypoints = false,
  }) =>
      _mapbox.getDrivingPathThrough(
        waypoints,
        snapWaypoints: snapWaypoints,
        preserveWaypoints: preserveWaypoints,
      );

  /// محاذاة نقاط تحكم الأدمن (يحافظ على النقاط؛ بدون sample 120م).
  Future<List<RoutePoint>> buildRoadAlignedRoute(
    List<RoutePoint> controlPoints,
  ) =>
      _mapbox.buildRoadAlignedRoute(controlPoints);

  Future<List<RoutePoint>> snapToRoads(
    List<RoutePoint> points, {
    double minSpacingMeters = 20,
  }) =>
      _mapbox.snapToRoads(points, minSpacingMeters: minSpacingMeters);

  List<RoutePoint> simplifyPoints(
    List<RoutePoint> input, {
    double minDistanceMeters = 25,
  }) =>
      RoutePlanGeometry.simplifyPoints(
        input,
        minDistanceMeters: minDistanceMeters,
      );

  double totalDistanceMeters(List<RoutePoint> points) =>
      RoutePlanGeometry.totalDistanceMeters(points);

  Stream<List<PlannedRoute>> watchLineRoutes(String lineName) {
    return _col.where('lineName', isEqualTo: lineName).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => PlannedRoute.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) => a.direction.index.compareTo(b.direction.index));
      return list;
    });
  }

  Stream<List<PlannedRoute>> watchDriverRoutes(String driver ind) {
    return _col.where('createdBy', isEqualTo: driverId).snapshots().map((snap) {
      return snap.docs
          .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
          .toList();
    });
  }
}
