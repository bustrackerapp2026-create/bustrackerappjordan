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

  Future<DriverLineAssignment?> getApprovedForDriver(String driverId) async {
    final approved = await getApprovedAssignmentsForDriver(driverId, limit: 50);
    return approved.isEmpty ? null : approved.first;
  }

  /// التعيين التشغيلي المرتبط برقم الباص/السرفيس.
  /// يبقى driverId موجودًا فقط لتقييد قراءة السائق حسب صلاحيات Firestore.
  Future<DriverLineAssignment?> getApprovedForVehicle({
    required String driverId,
    required String busNumber,
  }) async {
    final driver = driverId.trim();
    final bus = busNumber.trim();
    if (driver.isEmpty || bus.isEmpty) return null;

    final snap = await _col
        .where('driverId', isEqualTo: driver)
        .where('busNumber', isEqualTo: bus)
        .limit(50)
        .get();

    DriverLineAssignment? approved;
    for (final doc in snap.docs) {
      final assignment = DriverLineAssignment.fromDoc(doc.id, doc.data());
      if (assignment.status != DriverLineAssignmentStatus.approved) continue;
      if (assignment.routeId.trim().isEmpty) continue;
      if (approved == null ||
          _timestampOf(assignment).isAfter(_timestampOf(approved))) {
        approved = assignment;
      }
    }
    return approved;
  }

  Future<DriverLineAssignment?> getPendingForDriver(String driverId) async {
    final id = driverId.trim();
    if (id.isEmpty) return null;

    final snap = await _col.where('driverId', isEqualTo: id).limit(200).get();
    DriverLineAssignment? pending;
    for (final doc in snap.docs) {
      final assignment = DriverLineAssignment.fromDoc(doc.id, doc.data());
      if (assignment.status != DriverLineAssignmentStatus.pending) continue;
      if (assignment.routeId.trim().isEmpty) continue;
      if (pending == null ||
          _timestampOf(assignment).isAfter(_timestampOf(pending))) {
        pending = assignment;
      }
    }
    return pending;
  }

  Future<DriverLineAssignment?> getPendingForVehicle({
    required String driverId,
    required String busNumber,
  }) async {
    final driver = driverId.trim();
    final bus = busNumber.trim();
    if (driver.isEmpty || bus.isEmpty) return null;

    final snap = await _col
        .where('driverId', isEqualTo: driver)
        .where('busNumber', isEqualTo: bus)
        .limit(200)
        .get();

    DriverLineAssignment? pending;
    for (final doc in snap.docs) {
      final assignment = DriverLineAssignment.fromDoc(doc.id, doc.data());
      if (assignment.status != DriverLineAssignmentStatus.pending) continue;
      if (assignment.routeId.trim().isEmpty) continue;
      if (pending == null ||
          _timestampOf(assignment).isAfter(_timestampOf(pending))) {
        pending = assignment;
      }
    }
    return pending;
  }

  Future<TransitLine?> getApprovedLineForDriver(String driverId) async {
    final assignment = await getApprovedForDriver(driverId);
    if (assignment == null) return null;
    final line = await _lines.getById(assignment.lineId);
    if (line == null || !line.isApproved) return null;
    return line;
  }

  Future<TransitLine?> getApprovedLineForVehicle({
    required String driverId,
    required String busNumber,
  }) async {
    final assignment = await getApprovedForVehicle(
      driverId: driverId,
      busNumber: busNumber,
    );
    if (assignment == null) return null;
    final line = await _lines.getById(assignment.lineId);
    if (line == null || !line.isApproved) return null;
    return line;
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
    required String busNumber,
    required String routeId,
    required String lineId,
  }) async {
    final driver = driverId.trim();
    final bus = busNumber.trim();
    final route = routeId.trim();
    final line = lineId.trim();
    if (driver.isEmpty || bus.isEmpty || route.isEmpty || line.isEmpty) {
      throw const TransitLineServiceException(
        'بيانات طلب التعيين غير مكتملة، ويجب تحديد رقم الباص/السرفيس.',
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
      'busNumber': bus,
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
      busNumber: bus,
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

  /// موافقة ذرية على حساب السائق + تعيين مساره المختار.
  /// تُستخدم في حالة المسار المعتمد الموجود مسبقًا، بحيث تظهر للأدمن
  /// كطلب واحد ولا يمكن أن تتم الموافقة على أحد الجزأين دون الآخر.
  Future<void> approveDriverAndAssignment({
    required String driverId,
    required String assignmentId,
    required String adminId,
  }) async {
    final driver = driverId.trim();
    final assignmentRef = _col.doc(assignmentId.trim());
    final userRef = _db.collection('users').doc(driver);
    final cleanAdmin = adminId.trim();

    if (driver.isEmpty || assignmentId.trim().isEmpty || cleanAdmin.isEmpty) {
      throw const TransitLineServiceException(
        'بيانات الموافقة غير مكتملة.',
        code: 'invalid-approval',
      );
    }

    await _db.runTransaction((tx) async {
      final assignmentSnap = await tx.get(assignmentRef);
      final userSnap = await tx.get(userRef);

      if (!assignmentSnap.exists || assignmentSnap.data() == null) {
        throw const TransitLineServiceException(
          'طلب تعيين المسار غير موجود.',
          code: 'assignment-not-found',
        );
      }
      if (!userSnap.exists || userSnap.data() == null) {
        throw const TransitLineServiceException(
          'حساب السائق غير موجود.',
          code: 'driver-not-found',
        );
      }

      final assignment = DriverLineAssignment.fromDoc(
        assignmentSnap.id,
        assignmentSnap.data()!,
      );
      if (assignment.driverId != driver) {
        throw const TransitLineServiceException(
          'طلب التعيين لا يخص هذا السائق.',
          code: 'driver-assignment-mismatch',
        );
      }
      if (assignment.status != DriverLineAssignmentStatus.pending) {
        throw const TransitLineServiceException(
          'طلب التعيين ليس بانتظار المراجعة.',
          code: 'not-pending',
        );
      }

      final routeSnap = await tx.get(_routesCol.doc(assignment.routeId));
      if (!routeSnap.exists || routeSnap.data() == null) {
        throw const TransitLineServiceException(
          'المسار المعين غير موجود.',
          code: 'route-not-found',
        );
      }
      final route = PlannedRoute.fromDoc(
        routeSnap.id,
        routeSnap.data()!,
      );
      if (!route.isApproved || route.points.length < 2) {
        throw const TransitLineServiceException(
          'المسار المعين غير معتمد أو غير مكتمل.',
          code: 'route-not-approved',
        );
      }
      if (route.lineId?.trim().isNotEmpty == true &&
          route.lineId!.trim() != assignment.lineId) {
        throw const TransitLineServiceException(
          'المسار لا يطابق الخط المسجل في طلب التعيين.',
          code: 'route-line-mismatch',
        );
      }

      final lineSnap =
          await tx.get(_db.collection('transitLines').doc(assignment.lineId));
      if (!lineSnap.exists ||
          lineSnap.data() == null ||
          lineSnap.data()!['status']?.toString() != 'approved') {
        throw const TransitLineServiceException(
          'الخط التشغيلي غير معتمد.',
          code: 'line-not-approved',
        );
      }

      final existingApproved = await _col
          .where('driverId', isEqualTo: driver)
          .where(
            'status',
            isEqualTo: DriverLineAssignmentStatus.approved.firestoreValue,
          )
          .get();
      for (final doc in existingApproved.docs) {
        if (doc.id == assignment.id) continue;
        final other = DriverLineAssignment.fromDoc(doc.id, doc.data());
        if (other.routeId == assignment.routeId) {
          throw const TransitLineServiceException(
            'هذا المسار معيّن للسائق بالفعل.',
            code: 'approved-route-exists',
          );
        }
      }

      final now = FieldValue.serverTimestamp();
      tx.update(userRef, {
        'isVerified': true,
        'isRejected': false,
        'routeId': assignment.routeId,
        'updatedAt': now,
        'verifiedAt': now,
      });
      tx.update(assignmentRef, {
        'status': DriverLineAssignmentStatus.approved.firestoreValue,
        'reviewedBy': cleanAdmin,
        'reviewedAt': now,
        'reviewNote': FieldValue.delete(),
        'updatedAt': now,
      });
    });
  }

  /// رفض ذري لحساب السائق + طلب تعيين المسار.
  /// يُستخدم عندما يكون للسائق طلب مسار قائم، حتى لا يبقى التعيين معلقًا
  /// بعد رفض حساب السائق.
  Future<void> rejectDriverAndAssignment({
    required String driverId,
    required String assignmentId,
    required String adminId,
    String? reason,
  }) async {
    final driver = driverId.trim();
    final assignmentRef = _col.doc(assignmentId.trim());
    final userRef = _db.collection('users').doc(driver);
    final cleanAdmin = adminId.trim();
    final cleanReason = reason?.trim();

    if (driver.isEmpty || assignmentId.trim().isEmpty || cleanAdmin.isEmpty) {
      throw const TransitLineServiceException(
        'بيانات الرفض غير مكتملة.',
        code: 'invalid-rejection',
      );
    }

    await _db.runTransaction((tx) async {
      final assignmentSnap = await tx.get(assignmentRef);
      final userSnap = await tx.get(userRef);

      if (!assignmentSnap.exists || assignmentSnap.data() == null) {
        throw const TransitLineServiceException(
          'طلب تعيين المسار غير موجود.',
          code: 'assignment-not-found',
        );
      }
      if (!userSnap.exists || userSnap.data() == null) {
        throw const TransitLineServiceException(
          'حساب السائق غير موجود.',
          code: 'driver-not-found',
        );
      }

      final assignment = DriverLineAssignment.fromDoc(
        assignmentSnap.id,
        assignmentSnap.data()!,
      );
      if (assignment.driverId != driver) {
        throw const TransitLineServiceException(
          'طلب التعيين لا يخص هذا السائق.',
          code: 'driver-assignment-mismatch',
        );
      }
      if (assignment.status != DriverLineAssignmentStatus.pending) {
        throw const TransitLineServiceException(
          'طلب التعيين ليس بانتظار المراجعة.',
          code: 'not-pending',
        );
      }

      final now = FieldValue.serverTimestamp();
      tx.update(userRef, {
        'isVerified': false,
        'isRejected': true,
        'updatedAt': now,
      });
      tx.update(assignmentRef, {
        'status': DriverLineAssignmentStatus.rejected.firestoreValue,
        'reviewedBy': cleanAdmin,
        'reviewedAt': now,
        if (cleanReason != null && cleanReason.isNotEmpty)
          'reviewNote': cleanReason
        else
          'reviewNote': FieldValue.delete(),
        'updatedAt': now,
      });
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
