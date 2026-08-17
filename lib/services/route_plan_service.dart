import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/arabic_search.dart';
import '../models/planned_route.dart';
import '../models/route_point.dart';
import 'route_plan/route_plan_geometry.dart';
import 'route_plan/route_plan_mapbox.dart';

class RoutePlanService with RoutePlanGeometry, RoutePlanMapbox {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('plannedRoutes');

  // NOTE: truncated emergency - will use full file
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
    throw UnimplementedError('RESTORE FULL FILE');
  }
}
