import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/driver_line_assignment.dart';
import '../models/transit_line.dart';
import 'transit_line_service.dart';

/// إدارة طلبات تعيين الخطوط الرسمية للسائقين.
class DriverLineAssignmentService {
  DriverLineAssignmentService._();
  static final DriverLineAssignmentService instance =
      DriverLineAssignmentService._();
  factory DriverLineAssignmentService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TransitLineService _lines = TransitLineService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('driverLineAssignments');

  Future<DriverLineAssignment?> getById(String assignmentId) async {
    if (assignmentId.trim().isEmpty) return null;
    final snap = await _col.doc(assignmentId.trim()).get();
    if (!snap.exists || snap.data() == null) return null;
    return DriverLineAssignment.fromDoc(snap.id, snap.data()!);
  }

  Future<DriverLineAssignment?> getApprovedForDriver(String driverId) async {
    final id = driverId.trim();
    if (id.isEmpty) return null;

    final snap = await _col.where('driverId', isEqualTo: id).limit(50).get();
    DriverLineAssignment? approved;
    for (final doc in snap.docs) {
      final assignment = DriverLineAssignment.fromDoc(doc.id, doc.data());
      if (assignment.status == DriverLineAssignmentStatus.approved) {
        if (approved == null) {
          approved = assignment;
        } else if (_timestampOf(assignment).isAfter(_timestampOf(approved))) {
          approved = assignment;
        }
      }
    }
    return approved;
  }

  Future<TransitLine?> getApprovedLineForDriver(String driverId) async {
    final assignment = await getApprovedForDriver(driverId);
    if (assignment == null) return null;
    final line = await _lines.getById(assignment.lineId);
    if (line == null || !line.isApproved) return null;
    return line;
  }

  Future<List<DriverLineAssignment>> listForDriver(
    String driverId, {
    int limit = 50,
  }) async {
    final id = driverId.trim();
    if (id.isEmpty) return const [];

    final snap = await _col.where('driverId', isEqualTo: id).limit(200).get();
    final result = snap.docs
        .map((doc) => DriverLineAssignment.fromDoc(doc.id, doc.data()))
        .toList();
    result.sort((a, b) => _timestampOf(b).compareTo(_timestampOf(a)));
    return result.take(limit.clamp(1, 200)).toList();
  }

  Stream<List<DriverLineAssignment>> watchDriverAssignments(
    String driverId,
  ) {
    final id = driverId.trim();
    if (id.isEmpty) return const Stream.empty();

    return _col.where('driverId', isEqualTo: id).snapshots().map((snap) {
      final result = snap.docs
          .map((doc) => DriverLineAssignment.fromDoc(doc.id, doc.data()))
          .toList();
      result.sort((a, b) => _timestampOf(b).compareTo(_timestampOf(a)));
      return result;
    });
  }

  Stream<List<DriverLineAssignment>> watchPendingForAdmin() {
    return _col
        .where(
          'status',
          isEqualTo: DriverLineAssignmentStatus.pending.firestoreValue,
        )
        .snapshots()
        .map((snap) {
      final result = snap.docs
          .map((doc) => DriverLineAssignment.fromDoc(doc.id, doc.data()))
          .toList();
      result.sort((a, b) => _timestampOf(a).compareTo(_timestampOf(b)));
      return result;
    });
  }

  Future<DriverLineAssignment> requestAssignment({
    required String driverId,
    required String lineId,
  }) async {
    final driver = driverId.trim();
    final line = lineId.trim();
    if (driver.isEmpty || line.isEmpty) {
      throw const TransitLineServiceException(
        'بيانات طلب التعيين غير مكتملة.',
        code: 'invalid-request',
      );
    }

    final selectedLine = await _lines.getById(line);
    if (selectedLine == null) {
      throw const TransitLineServiceException(
        'الخط المطلوب غير موجود.',
        code: 'line-not-found',
      );
    }
    if (!selectedLine.isApproved) {
      throw const TransitLineServiceException(
        'لا يمكن طلب تعيين خط غير معتمد.',
        code: 'line-not-approved',
      );
    }

    final existing = await listForDriver(driver, limit: 200);
    final activeOrPending = existing.where(
      (item) =>
          item.lineId == line &&
          (item.status == DriverLineAssignmentStatus.pending ||
              item.status == DriverLineAssignmentStatus.approved),
    );
    if (activeOrPending.isNotEmpty) {
      return activeOrPending.first;
    }

    final approvedOther = existing.where(
      (item) => item.status == DriverLineAssignmentStatus.approved,
    );
    if (approvedOther.isNotEmpty) {
      throw const TransitLineServiceException(
        'لديك خط معتمد حاليًا. يجب إلغاء التعيين الحالي قبل طلب خط آخر.',
        code: 'approved-line-exists',
      );
    }

    final ref = _col.doc();
    await ref.set({
      'driverId': driver,
      'lineId': line,
      'status': DriverLineAssignmentStatus.pending.firestoreValue,
      'requestedBy': driver,
      'requestedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return DriverLineAssignment(
      id: ref.id,
      driverId: driver,
      lineId: line,
      requestedBy: driver,
      status: DriverLineAssignmentStatus.pending,
    );
  }

  Future<void> approveAssignment({
    required String assignmentId,
    required String adminId,
  }) async {
    final assignment = await getById(assignmentId);
    if (assignment == null) {
      throw const TransitLineServiceException(
        'طلب التعيين غير موجود.',
        code: 'not-found',
      );
    }

    final line = await _lines.getById(assignment.lineId);
    if (line == null || !line.isApproved) {
      throw const TransitLineServiceException(
        'لا يمكن اعتماد تعيين لخط غير معتمد.',
        code: 'line-not-approved',
      );
    }

    final current = await getApprovedForDriver(assignment.driverId);
    if (current != null && current.id != assignment.id) {
      throw const TransitLineServiceException(
        'لدى السائق خط معتمد بالفعل.',
        code: 'approved-line-exists',
      );
    }

    await _col.doc(assignment.id).update({
      'status': DriverLineAssignmentStatus.approved.firestoreValue,
      'reviewedBy': adminId.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNote': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectAssignment({
    required String assignmentId,
    required String adminId,
    String? reason,
  }) async {
    final assignment = await getById(assignmentId);
    if (assignment == null) {
      throw const TransitLineServiceException(
        'طلب التعيين غير موجود.',
        code: 'not-found',
      );
    }

    final cleanReason = reason?.trim();
    await _col.doc(assignment.id).update({
      'status': DriverLineAssignmentStatus.rejected.firestoreValue,
      'reviewedBy': adminId.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      if (cleanReason != null && cleanReason.isNotEmpty)
        'reviewNote': cleanReason
      else
        'reviewNote': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> revokeAssignment({
    required String assignmentId,
    required String adminId,
    String? reason,
  }) async {
    final assignment = await getById(assignmentId);
    if (assignment == null) {
      throw const TransitLineServiceException(
        'تعيين السائق غير موجود.',
        code: 'not-found',
      );
    }

    final cleanReason = reason?.trim();
    await _col.doc(assignment.id).update({
      'status': DriverLineAssignmentStatus.revoked.firestoreValue,
      'reviewedBy': adminId.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      if (cleanReason != null && cleanReason.isNotEmpty)
        'reviewNote': cleanReason
      else
        'reviewNote': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  DateTime _timestampOf(DriverLineAssignment assignment) {
    return assignment.reviewedAt ??
        assignment.requestedAt ??
        assignment.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
