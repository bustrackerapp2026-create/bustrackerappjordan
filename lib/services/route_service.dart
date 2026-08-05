import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import '../models/route_stop_model.dart';

/// خدمة إدارة خطوط السير (Routes)
/// مسؤولة عن جلب البيانات من Firestore ومعالجتها
class RouteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── 1. جلب قائمة المسارات النشطة (بيانات خفيفة) ──────────────

  /// ✅ جلب جميع المسارات النشطة (isActive == true)
  /// يتم جلب البيانات الأساسية فقط (بدون الإحداثيات الثقيلة)
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

  /// ✅ جلب مسار واحد بواسطة ID (بيانات أساسية فقط)
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

  // ─── 2. جلب إحداثيات المسار (بيانات ثقيلة، مقسمة إلى Chunks) ──

  /// ✅ جلب جميع إحداثيات مسار معين (مجموعة Chunks)
  /// هذه الدالة تجمع الأجزاء (Chunks) لإعادة المسار الكامل
  Future<List<GeoPoint>> fetchRouteCoordinates(String routeId) async {
    try {
      final querySnapshot = await _firestore
          .collection('routeCoordinates')
          .where('routeId', isEqualTo: routeId)
          .orderBy('chunkIndex')
          .get();

      List<GeoPoint> allCoordinates = [];
      for (final doc in querySnapshot.docs) {
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

  /// ✅ جلب جزء واحد فقط (Chunk) من إحداثيات المسار
  /// مفيد لتقليل استهلاك البيانات عند العرض الجزئي
  Future<List<GeoPoint>> fetchRouteCoordinatesChunk(
      String routeId, int chunkIndex) async {
    try {
      final querySnapshot = await _firestore
          .collection('routeCoordinates')
          .where('routeId', isEqualTo: routeId)
          .where('chunkIndex', isEqualTo: chunkIndex)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return (data['coordinates'] as List<dynamic>?)
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

  // ─── 3. جلب محطات المسار (Subcollection) ──────────────────────

  /// ✅ جلب محطات مسار معين (مثل مجمع الشمال، دوار المدينة)
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
