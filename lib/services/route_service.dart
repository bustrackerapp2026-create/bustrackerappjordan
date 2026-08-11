import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import '../models/route_stop_model.dart';

/// خدمة إدارة خطوط السير (Routes)
class RouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── 1. جلب قائمة المسارات النشطة ─────────────────────────────

  Stream<List<RouteModel>> getActiveRoutesStream() {
    return _firestore
        .collection('routes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
    }).handleError((error) {
      if (kDebugMode) {
        debugPrint('❌ [RouteService] خطأ في جلب المسارات النشطة: $error');
      }
      return <RouteModel>[];
    });
  }

  Future<RouteModel?> getRouteById(String routeId) async {
    try {
      final doc = await _firestore.collection('routes').doc(routeId).get();
      if (doc.exists) {
        return RouteModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [RouteService] خطأ في جلب المسار $routeId: $e');
      }
      return null;
    }
  }

  // ─── 2. جلب إحداثيات المسار ───────────────────────────────────

  /// جلب كل أجزاء الإحداثيات ثم ترتيبها محلياً (بدون orderBy)
  /// لتجنّب الحاجة لفهرس مركّب في Firestore.
  Future<List<GeoPoint>> fetchRouteCoordinates(String routeId) async {
    try {
      final querySnapshot = await _firestore
          .collection('routeCoordinates')
          .where('routeId', isEqualTo: routeId)
          .get();

      final docs = querySnapshot.docs.toList()
        ..sort((a, b) {
          final ai = (a.data()['chunkIndex'] as num?)?.toInt() ?? 0;
          final bi = (b.data()['chunkIndex'] as num?)?.toInt() ?? 0;
          return ai.compareTo(bi);
        });

      final List<GeoPoint> allCoordinates = [];
      for (final doc in docs) {
        final data = doc.data();
        final chunkCoords = (data['coordinates'] as List<dynamic>?)
                ?.map((e) => e as GeoPoint)
                .toList() ??
            [];
        allCoordinates.addAll(chunkCoords);
      }

      if (kDebugMode) {
        debugPrint(
            '✅ [RouteService] تم جلب ${allCoordinates.length} نقطة للمسار $routeId');
      }
      return allCoordinates;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [RouteService] خطأ في جلب إحداثيات المسار $routeId: $e');
      }
      return [];
    }
  }

  /// جلب جزء واحد بالمعرّف المباشر (بدون استعلام مركّب)
  Future<List<GeoPoint>> fetchRouteCoordinatesChunk(
      String routeId, int chunkIndex) async {
    try {
      final doc = await _firestore
          .collection('routeCoordinates')
          .doc('${routeId}_c$chunkIndex')
          .get();

      if (doc.exists) {
        final data = doc.data();
        return (data?['coordinates'] as List<dynamic>?)
                ?.map((e) => e as GeoPoint)
                .toList() ??
            [];
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '❌ [RouteService] خطأ في جلب الجزء $chunkIndex للمسار $routeId: $e');
      }
      return [];
    }
  }

  // ─── 3. جلب محطات المسار ─────────────────────────────────────

  Stream<List<RouteStopModel>> getRouteStopsStream(String routeId) {
    return _firestore
        .collection('routes')
        .doc(routeId)
        .collection('stops')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RouteStopModel.fromFirestore(doc))
          .toList();
    });
  }
}
