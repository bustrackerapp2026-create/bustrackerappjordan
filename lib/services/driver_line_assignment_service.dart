import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/driver_line_assignment.dart';
import '../models/planned_route.dart';
import '../models/transit_line.dart';
import 'transit_line_service.dart';

/// إدارة طلبات تعيين المسارات الرسمية للسائقين.
class DriverLineAssignmentService {
  DriverLineAssignmentService._();
  static final DriverLineAssignmentService instance =
      DriverLineAssignmentService._();
  factory DriverLineAssignmentService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TransitLineService _lines = TransitLineService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('driverLineAssignments');

  CollectionReference<Map<String, dynamic>> get _routesCol =>
      _db.collection('plannedRoutes');

  Future<DriverLineAssignment?> getById(String assignmentId) async {
    if (assignmentId.trim().isEmpty) return null;
    final snap = await _col.doc(assignmentId.trim()).get();
    if (!snap.exists || snap.data() == null) return null;
    return DriverLineAssignment.fromDoc(snap.id, snap.data()!);
  }

  /// جميع التعيينات المعتمدة للسائق. يمكن للسائق امتلاك مسارين منفصلين
  /// (مثلاً ذهاب وإياب) ما دام كل واحد منهما routeId مختلفًا.
  Future<List<DriverLineAssignment>> getApprovedAssignmentsForDriver(
    String driverId, {
    int limit = 50,
  }) async {
    final id = driverId.trim();
    if (id.isEmpty) return const [];

    final snap = await _col.where('driverId', isEqualTo: id).limit(200).get();
    final approved = snap.docs
        .map((doc) => DriverLineAssignment.fromDoc(doc.id, doc.data()))
        .where((item) =>
            item.status == DriverLineAssignmentStatus.approved &&
            item.routeId.trim().isNotEmpty)
        .toList();
    approved.sort((a, b) => _timestampOf(b).compareTo(_timestampOf(a)));
    return approved.take(limit.clamp(1, 200)).toList();
  }

  /// توافق خلفي مع الكود الحالي الذي يفترض تعيينًا واحدًا فقط.
  Future<DriverLineAssignment?> getApprovedForDriver(String driverId) async {
    final approved = await getApprovedAssignmentsForDriver(driverId, limit: 50);
    return approved.isEmpty ? null : approved.first;
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

  Future<PlannedRoute?> _getRouteById(String routeId) async {
    final id = routeId.trim();
    if (id.isEmpty) return null;

    final snap = await _routesCol.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return PlannedRoute.fromDoc(snap.id, snap.data()!);
  }

  Future<DriverLineAssignment> requestAssignment({
    required String driverId,
    required String routeId,
    required String lineId,
  }) async {
    final driver = driverId.trim();
    final route = routeId.trim();
    final line = lineId.trim();
    if (driver.isEmpty || route.isEmpty || line.isEmpty) {
      throw const TransitLineServiceException(
        'بيانات طلب التعيين غير مكتملة.',
        code: 'invalid-request',
      );
    }

    final selectedRoute = await _getRouteById(route);
    if (selectedRoute == null) {
      throw const TransitLineServiceException(
        'المسار المطلوب غير موجود.',
        code: 'route-not-found',
      );
    }
    if (!selectedRoute.isApproved || selectedRoute.points.length < 2) {
      throw const TransitLineServiceException(
        'لا يمكن طلب تعيين مسار غير معتمد أو غير مكتمل.',
        code: 'route-not-approved',
      );
    }

    final routeLineId = selectedRoute.lineId?.trim();
    if (routeLineId != null &&
        routeLineId.isNotEmpty &&
        routeLineId != line) {
      throw const TransitLineServiceException(
        'الخط المرسل لا يطابق الخط المرتبط بالمسار المختار.',
        code: 'route-line-mismatch',
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
          item.routeId == route &&
          (item.status == DriverLineAssignmentStatus.pending ||
              item.status == DriverLineAssignmentStatus.approved),
    );
    if (activeOrPending.isNotEmpty) {
      return activeOrPending.first;
    }

    final ref = _col.doc();
    await ref.set({
      'driverId': driver,
      'routeId': route,
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
      routeId: route,
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
    if (assignment.status != DriverLineAssignmentStatus.pending) {
      throw const TransitLineServiceException(
        'طلب التعيين ليس بانتظار المراجعة.',
        code: 'not-pending',
      );
    }

    final route = await _getRouteById(assignment.routeId);
    if (route == null ||
        !route.isApproved ||
        route.points.length < 2 ||
        (route.lineId?.trim().isNotEmpty == true &&
            route.lineId!.trim() != assignment.lineId)) {
      throw const TransitLineServiceException(
        'لا يمكن اعتماد تعيين لمسار غير صالح أو غير مرتبط بالخط المطلوب.',
        code: 'route-not-approved',
      );
    }

    final line = await _lines.getById(assignment.lineId);
    if (line == null || !line.isApproved) {
      throw const TransitLineServiceException(
        'لا يمكن اعتماد تعيين لخط غير معتمد.',
        code: 'line-not-approved',
      );
    }

    final approved = await getApprovedAssignmentsForDriver(
      assignment.driverId,
      limit: 200,
    );
    final duplicateRoute = approved.any(
      (item) =>
          item.id != assignment.id && item.routeId == assignment.routeId,
    );
    if (duplicateRoute) {
      throw const TransitLineServiceException(
        'هذا المسار معيّن للسائق بالفعل.',
        code: 'approved-route-exists',
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
