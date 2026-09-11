import 'package:cloud_firestore/cloud_firestore.dart';

/// الحالة التشغيلية للخط الرسمي.
enum TransitLineStatus {
  pending,
  approved,
  rejected,
  archived,
}

extension TransitLineStatusX on TransitLineStatus {
  String get firestoreValue {
    switch (this) {
      case TransitLineStatus.pending:
        return 'pending';
      case TransitLineStatus.approved:
        return 'approved';
      case TransitLineStatus.rejected:
        return 'rejected';
      case TransitLineStatus.archived:
        return 'archived';
    }
  }

  static TransitLineStatus fromString(String? value) {
    switch (value) {
      case 'approved':
        return TransitLineStatus.approved;
      case 'rejected':
        return TransitLineStatus.rejected;
      case 'archived':
        return TransitLineStatus.archived;
      default:
        return TransitLineStatus.pending;
    }
  }
}

/// الخط التشغيلي الرسمي، مستقل عن المسار الجغرافي.
class TransitLine {
  final String id;
  final String name;
  final String normalizedName;
  final String startName;
  final String? middleName;
  final String endName;
  final List<String> passingPlaces;
  final List<String> aliases;
  final TransitLineStatus status;
  final String proposedBy;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;

  const TransitLine({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.startName,
    required this.endName,
    required this.proposedBy,
    this.middleName,
    this.passingPlaces = const [],
    this.aliases = const [],
    this.status = TransitLineStatus.pending,
    this.approvedBy,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
  });

  bool get isApproved => status == TransitLineStatus.approved;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'normalizedName': normalizedName,
      'startName': startName,
      if (middleName != null && middleName!.trim().isNotEmpty)
        'middleName': middleName!.trim(),
      'endName': endName,
      'passingPlaces': passingPlaces,
      'aliases': aliases,
      'status': status.firestoreValue,
      'proposedBy': proposedBy,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TransitLine.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? readTimestamp(dynamic value) {
      return value is Timestamp ? value.toDate() : null;
    }

    List<String> readStringList(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return TransitLine(
      id: id,
      name: data['name']?.toString() ?? '',
      normalizedName: data['normalizedName']?.toString() ?? '',
      startName: data['startName']?.toString().trim() ?? '',
      middleName: data['middleName']?.toString().trim().isNotEmpty == true
          ? data['middleName']?.toString().trim()
          : null,
      endName: data['endName']?.toString().trim() ?? '',
      passingPlaces: readStringList(data['passingPlaces']),
      aliases: readStringList(data['aliases']),
      status: TransitLineStatusX.fromString(data['status']?.toString()),
      proposedBy: data['proposedBy']?.toString() ?? '',
      approvedBy: data['approvedBy']?.toString(),
      rejectionReason: data['rejectionReason']?.toString(),
      createdAt: readTimestamp(data['createdAt']),
      updatedAt: readTimestamp(data['updatedAt']),
      approvedAt: readTimestamp(data['approvedAt']),
    );
  }
}
