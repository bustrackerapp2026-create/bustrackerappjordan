import 'package:cloud_firestore/cloud_firestore.dart';

import 'planned_route.dart';

/// حالة طلب إنشاء/اعتماد مسار جديد من السائق.
enum DriverRouteRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

extension DriverRouteRequestStatusX on DriverRouteRequestStatus {
  String get firestoreValue {
    switch (this) {
      case DriverRouteRequestStatus.pending:
        return 'pending';
      case DriverRouteRequestStatus.approved:
        return 'approved';
      case DriverRouteRequestStatus.rejected:
        return 'rejected';
      case DriverRouteRequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static DriverRouteRequestStatus fromString(String? value) {
    switch (value) {
      case 'approved':
        return DriverRouteRequestStatus.approved;
      case 'rejected':
        return DriverRouteRequestStatus.rejected;
      case 'cancelled':
        return DriverRouteRequestStatus.cancelled;
      default:
        return DriverRouteRequestStatus.pending;
    }
  }
}

/// طلب مستقل لمسار غير موجود في الكتالوج المعتمد.
///
/// هذا الطلب لا يمنح السائق صلاحية تشغيلية بحد ذاته. بعد الموافقة يجب أن
/// يصبح له PlannedRoute معتمد، وعندها فقط يمكن إنشاء DriverLineAssignment
/// مرتبط بالـ routeId.
class DriverRouteRequest {
  final String id;
  final String driverId;

  /// هوية الخط المقترح، إن تم إنشاء TransitLine له أثناء الطلب.
  final String? lineId;

  /// هوية PlannedRoute بعد تسجيل المسار. تبقى null أثناء مرحلة الاقتراح.
  final String? routeId;

  final String lineName;
  final String startName;
  final String? middleName;
  final String endName;
  final RouteDirection direction;
  final DriverRouteRequestStatus status;
  final String requestedBy;
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverRouteRequest({
    required this.id,
    required this.driverId,
    required this.lineName,
    required this.startName,
    required this.endName,
    required this.direction,
    required this.requestedBy,
    this.lineId,
    this.routeId,
    this.middleName,
    this.status = DriverRouteRequestStatus.pending,
    this.reviewedBy,
    this.reviewNote,
    this.requestedAt,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == DriverRouteRequestStatus.pending;
  bool get isApproved => status == DriverRouteRequestStatus.approved;

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      if (lineId != null && lineId!.trim().isNotEmpty) 'lineId': lineId!.trim(),
      if (routeId != null && routeId!.trim().isNotEmpty)
        'routeId': routeId!.trim(),
      'lineName': lineName.trim(),
      'startName': startName.trim(),
      if (middleName != null && middleName!.trim().isNotEmpty)
        'middleName': middleName!.trim(),
      'endName': endName.trim(),
      'direction': direction.firestoreValue,
      'status': status.firestoreValue,
      'requestedBy': requestedBy,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewNote != null) 'reviewNote': reviewNote,
      if (requestedAt != null) 'requestedAt': Timestamp.fromDate(requestedAt!),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory DriverRouteRequest.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? readTimestamp(dynamic value) {
      return value is Timestamp ? value.toDate() : null;
    }

    return DriverRouteRequest(
      id: id,
      driverId: data['driverId']?.toString() ?? '',
      lineId: data['lineId']?.toString().trim().isNotEmpty == true
          ? data['lineId']?.toString().trim()
          : null,
      routeId: data['routeId']?.toString().trim().isNotEmpty == true
          ? data['routeId']?.toString().trim()
          : null,
      lineName: data['lineName']?.toString() ?? '',
      startName: data['startName']?.toString() ?? '',
      middleName: data['middleName']?.toString().trim().isNotEmpty == true
          ? data['middleName']?.toString().trim()
          : null,
      endName: data['endName']?.toString() ?? '',
      direction: RouteDirectionX.fromString(data['direction']?.toString()),
      status: DriverRouteRequestStatusX.fromString(
        data['status']?.toString(),
      ),
      requestedBy: data['requestedBy']?.toString() ?? '',
      reviewedBy: data['reviewedBy']?.toString(),
      reviewNote: data['reviewNote']?.toString(),
      requestedAt: readTimestamp(data['requestedAt']),
      reviewedAt: readTimestamp(data['reviewedAt']),
      createdAt: readTimestamp(data['createdAt']),
      updatedAt: readTimestamp(data['updatedAt']),
    );
  }
}
