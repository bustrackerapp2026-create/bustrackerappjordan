import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/arabic_search.dart';
import '../models/planned_route.dart';
import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_plan/route_plan_mapbox.dart';

/// خدمة مسارات plannedRoutes: قراءة، حفظ أدمن/سائق، تحسين هندسي.
class RoutePlanService with RoutePlanGeometry, RoutePlanMapbox {
  RoutePlanService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('plannedRoutes');

  Stream<List<PlannedRoute>> watchLineRoutes(String lineName) {
    return _col.where('lineName', isEqualTo: lineName).snapshots().map((snap) {
      return snap.docs
          .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
          .toList();
    });
  }

  Stream<List<PlannedRoute>> watchApprovedRoutesForLine(String lineName) {
    return _col
        .where('lineName', isEqualTo: lineName)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
          .toList();
    });
  }

  Future<PlannedRoute?> getLineDirection({
    required String lineName,
    required RouteDirection direction,
  }) async {
    final snap = await _col
        .where('lineName', isEqualTo: lineName)
        .where('direction', isEqualTo: direction.firestoreValue)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return PlannedRoute.fromDoc(d.id, d.data());
  }

  Future<PlannedRoute?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return PlannedRoute.fromDoc(doc.id, doc.data()!);
  }

  Map<String, dynamic> _searchPayload(String lineName, List<String> aliases) {
    final keys = ArabicSearch.buildSearchKeys(lineName, aliases: aliases);
    return {
      'lineNameNormalized': ArabicSearch.normalize(lineName),
      'searchKeys': keys,
      'aliases': aliases,
    };
  }

  Future<PlannedRoute> saveAdminDrawnRoute({
    required String adminId,
    required String lineName,
    required RouteDirection direction,
    required List<RoutePoint> points,
    bool replaceExisting = true,
    List<String> aliases = const [],
    String? notes,
    String? lineStart,
    String? lineMiddle,
    String? lineEnd,
    bool alreadySnapped = false,
  }) async {
    if (adminId.isEmpty) throw ArgumentError('adminId مطلوب');
    if (lineName.trim().isEmpty) throw ArgumentError('اسم الخط مطلوب');

    final existing = await getLineDirection(
      lineName: lineName.trim(),
      direction: direction,
    );

    if (existing != null && !replaceExisting) {
      throw StateError('المسار موجود مسبقاً لهذا الخط والاتجاه');
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

    if (finalPoints.length < 2) {
      throw StateError('أضف نقطتين على الأقل على الخريطة');
    }

    final distance = totalDistanceMeters(finalPoints);
    final search = _searchPayload(lineName.trim(), aliases);

    final payload = <String, dynamic>{
      'createdBy': adminId,
      'driverId': adminId,
      'lineName': lineName.trim(),
      'direction': direction.firestoreValue,
      'points': finalPoints.map((p) => p.toMap()).toList(),
      'status': PlannedRouteStatus.approved.firestoreValue,
      'editRequestPending': false,
      'reRecordAllowed': false,
      'distanceMeters': distance,
      'source': RouteSource.admin.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      ...search,
    };
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }
    if (lineStart != null && lineStart.trim().isNotEmpty) {
      payload['lineStart'] = lineStart.trim();
    }
    if (lineMiddle != null && lineMiddle.trim().isNotEmpty) {
      payload['lineMiddle'] = lineMiddle.trim();
    }
    if (lineEnd != null && lineEnd.trim().isNotEmpty) {
      payload['lineEnd'] = lineEnd.trim();
    }

    if (existing == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(payload);
      return PlannedRoute(
        id: ref.id,
        createdBy: adminId,
        lineName: lineName.trim(),
        direction: direction,
        points: finalPoints,
        status: PlannedRouteStatus.approved,
        distanceMeters: distance,
        source: RouteSource.admin,
        searchKeys: List<String>.from(search['searchKeys'] as List),
        aliases: List<String>.from(search['aliases'] as List),
        notes: notes,
      );
    }

    await _col.doc(existing.id).update(payload);
    return PlannedRoute(
      id: existing.id,
      createdBy: adminId,
      lineName: lineName.trim(),
      direction: direction,
      points: finalPoints,
      status: PlannedRouteStatus.approved,
      distanceMeters: distance,
      source: RouteSource.admin,
      searchKeys: List<String>.from(search['searchKeys'] as List),
      aliases: List<String>.from(search['aliases'] as List),
      notes: notes,
    );
  }

  Future<void> requestEdit({
    required String routeId,
    required String reason,
    required String requestedBy,
  }) async {
    final r = reason.trim();
    await _col.doc(routeId).update({
      'editRequestPending': true,
      if (r.isNotEmpty) 'notes': r,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoute(String routeId) async {
    await _col.doc(routeId).delete();
  }

  Stream<List<PlannedRoute>> watchAllApprovedRoutes() {
    return _col
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .where((r) => r.points.length >= 2)
            .toList());
  }
}
