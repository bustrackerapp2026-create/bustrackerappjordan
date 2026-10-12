import 'package:cloud_firestore/cloud_firestore.dart';

/// محطة ثابتة مرتبطة بـPlannedRoute محدد.
///
/// العلاقة بالمسار تأتي من Firestore parent path:
/// plannedRoutes/{routeId}/stops/{stopId}
///
/// لا يخزن النموذج routeId أو direction أو أي قيمة مشتقة هندسيًا.
class PlannedRouteStopModel {
  final String id;
  final String name;
  final GeoPoint location;
  final int order;
  final bool isMajor;

  PlannedRouteStopModel({
    required this.id,
    required this.name,
    required this.location,
    required this.order,
    this.isMajor = false,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('stopId مطلوب.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('اسم المحطة مطلوب.');
    }
    if (order < 0) {
      throw ArgumentError('order يجب أن يكون >= 0.');
    }
  }

  factory PlannedRouteStopModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawLocation = data['location'];
    if (rawLocation is! GeoPoint) {
      throw const FormatException('location يجب أن تكون GeoPoint.');
    }

    final rawOrder = data['order'];
    if (rawOrder is! int) {
      if (rawOrder is num && rawOrder.isFinite && rawOrder == rawOrder.truncateToDouble()) {
        return PlannedRouteStopModel(
          id: id,
          name: data['name']?.toString() ?? '',
          location: rawLocation,
          order: rawOrder.toInt(),
          isMajor: data['isMajor'] == true,
        );
      }
      throw const FormatException('order يجب أن يكون int.');
    }

    return PlannedRouteStopModel(
      id: id,
      name: data['name']?.toString() ?? '',
      location: rawLocation,
      order: rawOrder,
      isMajor: data['isMajor'] == true,
    );
  }

  factory PlannedRouteStopModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PlannedRouteStopModel.fromMap(doc.id, doc.data() ?? const {});
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'location': location,
      'order': order,
      if (isMajor) 'isMajor': true,
    };
  }
}
