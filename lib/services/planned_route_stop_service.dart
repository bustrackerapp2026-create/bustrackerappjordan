import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/planned_route_stop_model.dart';

/// قارئ المحطات الثابتة المرتبطة بمسار PlannedRoute.
///
/// المسار: plannedRoutes/{routeId}/stops/{stopId}
/// هذه الخدمة للقراءة فقط؛ لا تنشئ أو تعدل أو تحذف Stops.
class PlannedRouteStopService {
  PlannedRouteStopService._();
  static final PlannedRouteStopService instance = PlannedRouteStopService._();
  factory PlannedRouteStopService() => instance;

  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _stops(String routeId) {
    return _db.collection('plannedRoutes').doc(routeId).collection('stops');
  }

  /// مراقبة Stops بترتيب [order].
  ///
  /// routeId فارغ يعني أنه لا يوجد مصدر صالح للقراءة، لذلك يعاد stream فارغ.
  Stream<List<PlannedRouteStopModel>> watchStops(String routeId) {
    final id = routeId.trim();
    if (id.isEmpty) return const Stream.empty();

    return _stops(id).orderBy('order').snapshots().map((snap) {
      return snap.docs
          .map(PlannedRouteStopModel.fromFirestore)
          .toList(growable: false);
    });
  }

  /// جلب لقطة واحدة من Stops بترتيب [order].
  Future<List<PlannedRouteStopModel>> fetchStops(String routeId) async {
    final id = routeId.trim();
    if (id.isEmpty) return const [];

    final snap = await _stops(id).orderBy('order').get();
    return snap.docs
        .map(PlannedRouteStopModel.fromFirestore)
        .toList(growable: false);
  }
}
