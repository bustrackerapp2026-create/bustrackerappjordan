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
