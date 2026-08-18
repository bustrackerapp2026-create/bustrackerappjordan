import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/map_text_label.dart';

/// خدمة التسميات النصية على الخريطة (Firestore: mapTextLabels).
class MapTextLabelService {
  MapTextLabelService._();
  static final MapTextLabelService instance = MapTextLabelService._();
  factory MapTextLabelService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('mapTextLabels');

  Stream<List<MapTextLabel>> watchApproved() {
    return _col
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MapTextLabel.fromDoc(d.id, d.data()))
              .where((m) => m.text.isNotEmpty)
              .toList(),
        );
  }

  Stream<List<MapTextLabel>> watchAllForAdmin() {
    return _col.snapshots().map(
          (snap) => snap.docs
              .map((d) => MapTextLabel.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<MapTextLabel> createLabel({
    required String text,
    required double latitude,
    required double longitude,
    required String createdBy,
    double fontSize = 14,
    double rotation = 0,
    int colorArgb = 0xFF1A237E,
    String status = 'approved',
  }) async {
    final t = text.trim();
    if (t.isEmpty) throw ArgumentError('النص مطلوب');
    if (createdBy.isEmpty) throw ArgumentError('createdBy مطلوب');

    final payload = <String, dynamic>{
      'text': t,
      'latitude': latitude,
      'longitude': longitude,
      'fontSize': fontSize.clamp(8, 36),
      'rotation': rotation % 360,
      'colorArgb': colorArgb,
      'status': status,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final ref = await _col.add(payload);
    return MapTextLabel(
      id: ref.id,
      text: t,
      latitude: latitude,
      longitude: longitude,
      fontSize: fontSize,
      rotation: rotation,
      colorArgb: colorArgb,
      status: status,
      createdBy: createdBy,
    );
  }

  Future<void> updateLabel({
    required String id,
    required String text,
    double? fontSize,
    double? rotation,
    int? colorArgb,
    double? latitude,
    double? longitude,
    String? status,
  }) async {
    if (id.isEmpty) throw ArgumentError('id مطلوب');
    final t = text.trim();
    if (t.isEmpty) throw ArgumentError('النص مطلوب');

    final payload = <String, dynamic>{
      'text': t,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fontSize != null) payload['fontSize'] = fontSize.clamp(8, 36);
    if (rotation != null) payload['rotation'] = rotation % 360;
    if (colorArgb != null) payload['colorArgb'] = colorArgb;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (status != null) payload['status'] = status;

    await _col.doc(id).update(payload);
  }

  Future<void> deleteLabel(String id) async {
    if (id.isEmpty) return;
    await _col.doc(id).delete();
  }
}
