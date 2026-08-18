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
    if (id.isEmpty) throw ArgumentError('id مطلوب');
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('اسم المعلم مطلوب');

    final keys = ArabicSearch.buildSearchKeys(n);
    final payload = <String, dynamic>{
      'name': n,
      'type': type.firestoreValue,
      'searchKeys': keys,
      'updatedAt': FieldValue.serverTimestamp(),
      'notes': (notes == null || notes.trim().isEmpty)
          ? FieldValue.delete()
          : notes.trim(),
    };
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (status != null) payload['status'] = status.firestoreValue;

    await _col.doc(id).update(payload);
  }

  Future<void> deleteLandmark(String id) async {
    if (id.isEmpty) return;
    await _col.doc(id).delete();
  }
}
