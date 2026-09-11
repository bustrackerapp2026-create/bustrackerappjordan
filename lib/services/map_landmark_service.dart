import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/arabic_search.dart';
import '../models/map_landmark.dart';

/// خدمة معالم الخريطة الخاصة بالمشروع (Firestore: mapLandmarks).
class MapLandmarkService {
  MapLandmarkService._();
  static final MapLandmarkService instance = MapLandmarkService._();
  factory MapLandmarkService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('mapLandmarks');

  Stream<List<MapLandmark>> watchApproved() {
    return _col
        .where('status', isEqualTo: MapLandmarkStatus.approved.firestoreValue)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MapLandmark.fromDoc(d.id, d.data()))
              .where((m) => m.name.isNotEmpty)
              .toList(),
        );
  }

  Stream<List<MapLandmark>> watchAllForAdmin() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => MapLandmark.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<MapLandmark?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return MapLandmark.fromDoc(doc.id, doc.data()!);
  }

  Future<MapLandmark> createLandmark({
    required String name,
    required MapLandmarkType type,
    required double latitude,
    required double longitude,
    required String createdBy,
    String? notes,
    /// `admin` من لوحة الأدمن، `user` من مستخدم.
    String source = 'admin',
    MapLandmarkStatus status = MapLandmarkStatus.approved,
  }) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('اسم المعلم مطلوب');
    if (createdBy.isEmpty) throw ArgumentError('createdBy مطلوب');

    final keys = ArabicSearch.buildSearchKeys(n);
    final payload = <String, dynamic>{
      'name': n,
      'type': type.firestoreValue,
      'latitude': latitude,
      'longitude': longitude,
      'status': status.firestoreValue,
      'createdBy': createdBy,
      'source': source == 'user' ? 'user' : 'admin',
      'searchKeys': keys,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }

    final ref = await _col.add(payload);
    return MapLandmark(
      id: ref.id,
      name: n,
      type: type,
      latitude: latitude,
      longitude: longitude,
      status: status,
      createdBy: createdBy,
      notes: notes?.trim(),
      searchKeys: keys,
    );
  }

  Future<void> updateLandmark({
    required String id,
    required String name,
    required MapLandmarkType type,
    String? notes,
    double? latitude,
    double? longitude,
    MapLandmarkStatus? status,
  }) async {
    final n = name.trim();
    if (id.isEmpty || n.isEmpty) return;
    final payload = <String, dynamic>{
      'name': n,
      'type': type.firestoreValue,
      'searchKeys': ArabicSearch.buildSearchKeys(n),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notes != null) {
      final t = notes.trim();
      payload['notes'] = t.isEmpty ? FieldValue.delete() : t;
    }
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (status != null) payload['status'] = status.firestoreValue;
    await _col.doc(id).update(payload);
  }

  Future<void> deleteLandmark(String id) async {
    if (id.isEmpty) return;
    await _col.doc(id).delete();
  }

  /// إحصائيات المعالم + التسميات النصية (أسماء شوارع وغيرها).
  /// [fromAdmin] يشمل السجلات القديمة بدون حقل source.
  Future<Map<String, int>> getStats({bool useFallback = true}) async {
    try {
      final labels = _db.collection('mapTextLabels');
      final results = await Future.wait([
        _count(_col),
        _count(_col.where('source', isEqualTo: 'admin')),
        _count(_col.where('source', isEqualTo: 'user')),
        _count(
          _col.where(
            'status',
            isEqualTo: MapLandmarkStatus.approved.firestoreValue,
          ),
        ),
        _count(
          _col.where(
            'status',
            isEqualTo: MapLandmarkStatus.pending.firestoreValue,
          ),
        ),
        _count(
          _col.where(
            'status',
            isEqualTo: MapLandmarkStatus.rejected.firestoreValue,
          ),
        ),
        _count(labels),
        _count(labels.where('status', isEqualTo: 'approved')),
      ]);

      final total = results[0];
      final taggedAdmin = results[1];
      final fromUsers = results[2];
      final fromAdmin = total - fromUsers;

      return {
        'total': total,
        'fromAdmin': fromAdmin < 0 ? 0 : fromAdmin,
        'fromUsers': fromUsers,
        'taggedAdmin': taggedAdmin,
        'approved': results[3],
        'pending': results[4],
        'rejected': results[5],
        'textLabels': results[6],
        'textLabelsApproved': results[7],
      };
    } catch (e) {
      if (useFallback) {
        return {
          'total': 0,
          'fromAdmin': 0,
          'fromUsers': 0,
          'taggedAdmin': 0,
          'approved': 0,
          'pending': 0,
          'rejected': 0,
          'textLabels': 0,
          'textLabelsApproved': 0,
        };
      }
      throw Exception('فشل جلب إحصائيات المعالم: $e');
    }
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snap = await query.count().get();
    return snap.count ?? 0;
  }
}
