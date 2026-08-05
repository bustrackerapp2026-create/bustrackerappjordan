import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج محطة (Stop) ضمن مسار معين (Subcollection تحت routes)
/// يمثل نقطة توقف رئيسية أو فرعية على طول خط السير
class RouteStopModel {
  final String id;
  final String routeId;
  final String name;
  final GeoPoint location;
  final int order; // ترتيب المحطة في المسار (1، 2، 3...)
  final bool isMajor; // هل هي محطة رئيسية (مثل مجمع) أم فرعية؟

  const RouteStopModel({
    required this.id,
    required this.routeId,
    required this.name,
    required this.location,
    required this.order,
    required this.isMajor,
  });

  /// من Firestore إلى كائن
  factory RouteStopModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RouteStopModel(
      id: doc.id,
      routeId: data['routeId'] ?? '',
      name: data['name'] ?? 'بدون اسم',
      location: data['location'] as GeoPoint,
      order: data['order'] ?? 0,
      isMajor: data['isMajor'] ?? false,
    );
  }

  /// إلى Map للتخزين في Firestore
  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'name': name,
      'location': location,
      'order': order,
      'isMajor': isMajor,
    };
  }
}
