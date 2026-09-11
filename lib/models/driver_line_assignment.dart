import 'package:cloud_firestore/cloud_firestore.dart';

/// حالة طلب/تعيين الخط للسائق.
enum DriverLineAssignmentStatus {
  pending,
  approved,
  rejected,
  revoked,
}

extension DriverLineAssignmentStatusX on DriverLineAssignmentStatus {
  String get firestoreValue {
    switch (this) {
      case DriverLineAssignmentStatus.pending:
        return 'pending';
      case DriverLineAssignmentStatus.approved:
        return 'approved';
      case DriverLineAssignmentStatus.rejected:
        return 'rejected';
      case DriverLineAssignmentStatus.revoked:
        return 'revoked';
    }
  }

  static DriverLineAssignmentStatus fromString(String? value) {
    switch (value) {
      case 'approved':
        return DriverLineAssignmentStatus.approved;
      case 'rejected':
        return DriverLineAssignmentStatus.rejected;
      case 'revoked':
        return DriverLineAssignmentStatus.revoked;
      default:
        return DriverLineAssignmentStatus.pending;
    }
  }
}

/// تعيين خط رسمي لسائق بعد موافقة الأدمن.
class DriverLineAssignment {
  final String id;
  final String driverId;
  final String lineId;
  final DriverLineAssignmentStatus status;
  final String requestedBy;
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverLineAssignment({
    required this.id,
    required this.driverId,
    required this.lineId,
    required this.requestedBy,
    this.status = DriverLineAssignmentStatus.pending,
    this.reviewedBy,
    this.reviewNote,
    this.requestedAt,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isApproved => status == DriverLineAssignmentStatus.approved;

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'lineId': lineId,
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

  factory DriverLineAssignment.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? readTimestamp(dynamic value) {
      return value is Timestamp ? value.toDate() : null;
    }

    return DriverLineAssignment(
      id: id,
      driverId: data['driverId']?.toString() ?? '',
      lineId: data['lineId']?.toString() ?? '',
      status: DriverLineAssignmentStatusX.fromString(
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
