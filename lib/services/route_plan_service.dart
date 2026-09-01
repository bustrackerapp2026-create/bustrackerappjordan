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
  }) =>
      _mapbox.getDrivingPath(
        from: from,
        to: to,
        snapEndpoints: snapEndpoints,
        attachControlEndpoints: attachControlEndpoints,
      );

  Future<List<RoutePoint>> getDrivingPathThrough(
    List<RoutePoint> waypoints, {
    bool snapWaypoints = true,
  }) =>
      _mapbox.getDrivingPathThrough(
        waypoints,
        snapWaypoints: snapWaypoints,
      );

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

  Stream<List<PlannedRoute>> watchDriverRoutes(String driverId) {
    return _col
        .where('createdByDriverId', isEqualTo: driverId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => PlannedRoute.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) => a.direction.index.compareTo(b.direction.index));
      return list;
    });
  }

  Stream<List<PlannedRoute>> watchAllApprovedRoutes() {
    return _col.where('status', isEqualTo: 'approved').snapshots().map((snap) {
      final list =
          snap.docs.map((d) => PlannedRoute.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) {
        final byName = a.lineName.compareTo(b.lineName);
        if (byName != 0) return byName;
        return a.direction.index.compareTo(b.direction.index);
      });
      return list;
    });
  }

  Future<PlannedRoute?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return PlannedRoute.fromDoc(doc.id, doc.data()!);
  }

  /// Approved routes for a line name (exact match).
  Future<List<PlannedRoute>> getApprovedRoutesForLine(String lineName) async {
    final snap = await _col
        .where('lineName', isEqualTo: lineName.trim())
        .where('status', isEqualTo: 'approved')
        .get();
    return snap.docs
        .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
        .toList();
  }

  Future<PlannedRoute> saveAdminDrawnRoute({
    required String adminId,
    required String lineName,
    required RouteDirection direction,
    required List<RoutePoint> points,
    List<String> aliases = const [],
    String? notes,
    String lineStart = '',
    String? lineMiddle,
    String lineEnd = '',
    bool alreadySnapped = false,
  }) async {
    if (points.length < 2) {
      throw StateError('نقطتان على الأقل مطلوبة');
    }

    final List<RoutePoint> finalPoints;
    if (alreadySnapped && points.length >= 2) {
      final polished = await snapToRoads(points, minSpacingMeters: 10);
      finalPoints = polished.length >= 2
          ? simplifyPoints(polished, minDistanceMeters: 8)
          : simplifyPoints(points, minDistanceMeters: 8);
    } else {
      finalPoints = await buildRoadAlignedRoute(points);
    }

    if (finalPoints.length < minPointsToSave) {
      throw StateError(
        'المسار قصير جداً بعد المحاذاة (${finalPoints.length} نقطة). أضف نقاط تحكم أكثر.',
      );
    }

    final distance = totalDistanceMeters(finalPoints);
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'lineName': lineName.trim(),
      'direction': direction.name,
      'status': 'approved',
      'points': finalPoints.map((p) => p.toMap()).toList(),
      'aliases': aliases,
      'notes': notes,
      'lineStart': lineStart,
      'lineMiddle': lineMiddle,
      'lineEnd': lineEnd,
      'distanceMeters': distance,
      'createdByAdminId': adminId,
      'approvedByAdminId': adminId,
      'createdAt': now,
      'updatedAt': now,
      'approvedAt': now,
    };

    // Arabic search fields if available
    try {
      final search = ArabicSearch.routeSearchFields(
        lineName: lineName,
        aliases: aliases,
        lineStart: lineStart,
        lineMiddle: lineMiddle,
        lineEnd: lineEnd,
        notes: notes,
      );
      data.addAll(search);
    } catch (_) {}

    final ref = await _col.add(data);
    final saved = await ref.get();
    return PlannedRoute.fromDoc(saved.id, saved.data()!);
  }

  Future<void> deleteRoute(String routeId) async {
    await _col.doc(routeId).delete();
  }
}
