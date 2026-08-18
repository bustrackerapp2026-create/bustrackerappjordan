import 'package:cloud_firestore/cloud_firestore.dart';

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
}
