import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/arabic_search.dart';
import '../models/planned_route.dart';
import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_plan/route_plan_mapbox.dart';

/// خدمة مسارات الخطوط المشتركة (ذهاب/إياب).
/// المسار يُخزَّن مرة واحدة لكل (اسم خط + اتجاه) ويُعتمد تلقائياً.
///
/// التفويض:
/// - هندسة النقاط → [RoutePlanGeometry]
/// - Mapbox → [RoutePlanMapbox]
/// - Firestore → هذا الملف
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

  // ─── تفويض Mapbox / هندسة (نفس الـ API العام) ───

  Future<RoutePoint> snapPointToRoad(RoutePoint point) =>
      _mapbox.snapPointToRoad(point);

  Future<List<RoutePoint>> getDrivingPath({
    required RoutePoint from,
    required RoutePoint to,
    bool snapEndpoints = true,
  }) =>
      _mapbox.getDrivingPath(
        from: from,
        to: to,
        snapEndpoints: snapEndpoints,
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

  // ─── Firestore ───

  Stream<List<PlannedRoute>> watchLineRoutes(String lineName) {
    return _col.where('lineName', isEqualTo: lineName).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => PlannedRoute.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) => a.direction.index.compareTo(b.direction.index));
      return list;
    });
  }

  Stream<List<PlannedRoute>> watchDriverRoutes(String driverId) {
    return _col.where('createdBy', isEqualTo: driverId).snapshots().map((snap) {
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
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .where((r) => r.points.length >= 2)
            .toList());
  }

  Future<List<PlannedRoute>> searchApprovedRoutes(String query) async {
    final q = ArabicSearch.normalize(query);
    if (q.isEmpty) return const [];

    final snap = await _col.where('status', isEqualTo: 'approved').get();
    final results = <PlannedRoute>[];
    for (final d in snap.docs) {
      final r = PlannedRoute.fromDoc(d.id, d.data());
      if (r.points.length < 2) continue;
      if (ArabicSearch.matches(
        query: query,
        lineName: r.lineName,
        searchKeys: r.searchKeys,
        aliases: r.aliases,
      )) {
        results.add(r);
      }
    }
    results.sort((a, b) => a.lineName.compareTo(b.lineName));
    return results;
  }

  Future<List<String>> listApprovedLineNames() async {
    final snap = await _col.where('status', isEqualTo: 'approved').get();
    final names = <String>{};
    for (final d in snap.docs) {
      final n = d.data()['lineName']?.toString().trim() ?? '';
      if (n.isNotEmpty) names.add(n);
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<PlannedRoute?> getLineDirection({
    required String lineName,
    required RouteDirection direction,
  }) async {
    final q = await _col
        .where('lineName', isEqualTo: lineName.trim())
        .where('direction', isEqualTo: direction.firestoreValue)
        .limit(5)
        .get();
    if (q.docs.isEmpty) return null;

    PlannedRoute? approved;
    PlannedRoute? any;
    for (final d in q.docs) {
      final r = PlannedRoute.fromDoc(d.id, d.data());
      any ??= r;
      if (r.status == PlannedRouteStatus.approved && r.points.length >= 2) {
        approved = r;
        break;
      }
    }
    return approved ?? any;
  }

  @Deprecated('استخدم getLineDirection — المسارات مشتركة باسم الخط')
  Future<PlannedRoute?> getDriverDirection({
    required String driverId,
    required String lineName,
    required RouteDirection direction,
  }) =>
      getLineDirection(lineName: lineName, direction: direction);

  Map<String, dynamic> _searchPayload(String lineName, List<String> aliases) {
    final keys = ArabicSearch.buildSearchKeys(lineName, aliases: aliases);
    return {
      'lineNameNormalized': ArabicSearch.normalize(lineName),
      'searchKeys': keys,
      'aliases': aliases
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
    };
  }

  Future<PlannedRoute> saveRecordedRoute({
    required String driverId,
    required String lineName,
    required RouteDirection direction,
    required List<RoutePoint> rawPoints,
    bool snap = true,
    List<String> aliases = const [],
  }) async {
    if (driverId.isEmpty) throw ArgumentError('driverId مطلوب');
    if (lineName.trim().isEmpty) throw ArgumentError('اسم الخط مطلوب');

    final existing = await getLineDirection(
      lineName: lineName.trim(),
      direction: direction,
    );

    if (existing != null && existing.isLocked) {
      throw StateError(
        'مسار ${direction.labelAr} لخط «${lineName.trim()}» مخزّن مسبقاً. '
        'لا حاجة لتسجيله من جديد. لطلب تعديل اكتب السبب وانتظر موافقة الأدمن.',
      );
    }

    final points = snap
        ? await buildRoadAlignedRoute(rawPoints)
        : simplifyPoints(rawPoints);
    if (points.length < minPointsToSave) {
      throw StateError(
        'المسار قصير جداً (${points.length} نقطة). '
        'سجّل مسافة أطول قبل الحفظ.',
      );
    }

    final distance = totalDistanceMeters(points);
    final search = _searchPayload(lineName.trim(), aliases);
    final payload = <String, dynamic>{
      'createdBy': driverId,
      'driverId': driverId,
      'lineName': lineName.trim(),
      'direction': direction.firestoreValue,
      'points': points.map((p) => p.toMap()).toList(),
      'status': PlannedRouteStatus.approved.firestoreValue,
      'editRequestPending': false,
      'editRequestReason': FieldValue.delete(),
      'editRequestedBy': FieldValue.delete(),
      'reRecordAllowed': false,
      'distanceMeters': distance,
      'source': RouteSource.driver.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      ...search,
    };

    if (existing == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(payload);
      return PlannedRoute(
        id: ref.id,
        createdBy: driverId,
        lineName: lineName.trim(),
        direction: direction,
        points: points,
        status: PlannedRouteStatus.approved,
        distanceMeters: distance,
        source: RouteSource.driver,
        searchKeys: List<String>.from(search['searchKeys'] as List),
        aliases: List<String>.from(search['aliases'] as List),
      );
    }

    await _col.doc(existing.id).update(payload);
    return PlannedRoute(
      id: existing.id,
      createdBy: driverId,
      lineName: lineName.trim(),
      direction: direction,
      points: points,
      status: PlannedRouteStatus.approved,
      distanceMeters: distance,
      source: RouteSource.driver,
      searchKeys: List<String>.from(search['searchKeys'] as List),
      aliases: List<String>.from(search['aliases'] as List),
    );
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
    );
  }

  Future<void> requestEdit({
    required String routeId,
    required String reason,
    required String requestedBy,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) {
      throw ArgumentError('يجب كتابة سبب طلب التعديل');
    }
    await _col.doc(routeId).update({
      'editRequestPending': true,
      'editRequestReason': r,
      'editRequestedBy': requestedBy,
      'reRecordAllowed': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRoute(String routeId) async {
    await _col.doc(routeId).update({
      'status': PlannedRouteStatus.approved.firestoreValue,
      'editRequestPending': false,
      'reRecordAllowed': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRoute(String routeId, {String? reason}) async {
    await _col.doc(routeId).update({
      'status': PlannedRouteStatus.rejected.firestoreValue,
      'editRequestPending': false,
      'reRecordAllowed': false,
      if (reason != null) 'notes': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveEditRequest(String routeId) async {
    await _col.doc(routeId).update({
      'editRequestPending': false,
      'reRecordAllowed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> denyEditRequest(String routeId) async {
    await _col.doc(routeId).update({
      'editRequestPending': false,
      'reRecordAllowed': false,
      'editRequestReason': FieldValue.delete(),
      'editRequestedBy': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PlannedRoute>> watchPendingRoutes() {
    return _col
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .toList());
  }

  Stream<List<PlannedRoute>> watchEditRequests() {
    return _col
        .where('editRequestPending', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannedRoute.fromDoc(d.id, d.data()))
            .toList());
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

  Future<void> deleteRoute(String routeId) async {
    await _col.doc(routeId).delete();
  }
}
