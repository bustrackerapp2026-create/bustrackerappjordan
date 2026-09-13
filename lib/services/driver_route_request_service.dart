import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/driver_route_request.dart';
import '../models/planned_route.dart';

/// إدارة طلبات السائقين للمسارات غير الموجودة في الكتالوج المعتمد.
class DriverRouteRequestService {
  DriverRouteRequestService._();
  static final DriverRouteRequestService instance =
      DriverRouteRequestService._();
  factory DriverRouteRequestService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('driverRouteRequests');

  Future<DriverRouteRequest?> getById(String requestId) async {
    final id = requestId.trim();
    if (id.isEmpty) return null;

    final snap = await _col.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return DriverRouteRequest.fromDoc(snap.id, snap.data()!);
  }

  Stream<List<DriverRouteRequest>> watchForDriver(String driverId) {
    final id = driverId.trim();
    if (id.isEmpty) return const Stream.empty();

    return _col.where('driverId', isEqualTo: id).snapshots().map((snap) {
      final result = snap.docs
          .map((doc) => DriverRouteRequest.fromDoc(doc.id, doc.data()))
          .toList();
      result.sort((a, b) => _timestampOf(b).compareTo(_timestampOf(a)));
      return result;
    });
  }

  Stream<List<DriverRouteRequest>> watchPendingForAdmin() {
    return _col
        .where(
          'status',
          isEqualTo: DriverRouteRequestStatus.pending.firestoreValue,
        )
        .snapshots()
        .map((snap) {
      final result = snap.docs
          .map((doc) => DriverRouteRequest.fromDoc(doc.id, doc.data()))
          .toList();
      result.sort((a, b) => _timestampOf(a).compareTo(_timestampOf(b)));
      return result;
    });
  }

  Future<DriverRouteRequest?> getPendingForDriver(String driverId) async {
    final id = driverId.trim();
    if (id.isEmpty) return null;

    final snap = await _col.where('driverId', isEqualTo: id).limit(200).get();
    DriverRouteRequest? pending;
    for (final doc in snap.docs) {
      final request = DriverRouteRequest.fromDoc(doc.id, doc.data());
      if (!request.isPending) continue;
      if (pending == null ||
          _timestampOf(request).isAfter(_timestampOf(pending))) {
        pending = request;
      }
    }
    return pending;
  }

  Future<DriverRouteRequest> createRequest({
    required String driverId,
    required String lineName,
    required String startName,
    required String endName,
    required RouteDirection direction,
    String? middleName,
    String? lineId,
  }) async {
    final driver = driverId.trim();
    final name = lineName.trim();
    final start = startName.trim();
    final end = endName.trim();
    final middle = middleName?.trim();
    final cleanLineId = lineId?.trim();

    if (driver.isEmpty || name.isEmpty || start.isEmpty || end.isEmpty) {
      throw const DriverRouteRequestException(
        'بيانات طلب المسار غير مكتملة.',
        code: 'invalid-request',
      );
    }
    if (cleanLineId != null && cleanLineId.isEmpty) {
      throw const DriverRouteRequestException(
        'معرف الخط غير صالح.',
        code: 'invalid-line',
      );
    }

    final existing = await getPendingForDriver(driver);
    if (existing != null &&
        _sameRequest(existing,
            name: name,
            startName: start,
            middleName: middle,
            endName: end,
            direction: direction,
            lineId: cleanLineId)) {
      return existing;
    }

    final ref = _col.doc();
    await ref.set({
      'driverId': driver,
      if (cleanLineId != null && cleanLineId.isNotEmpty) 'lineId': cleanLineId,
      'lineName': name,
      'startName': start,
      if (middle != null && middle.isNotEmpty) 'middleName': middle,
      'endName': end,
      'direction': direction.firestoreValue,
      'status': DriverRouteRequestStatus.pending.firestoreValue,
      'requestedBy': driver,
      'requestedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return DriverRouteRequest(
      id: ref.id,
      driverId: driver,
      lineId: cleanLineId,
      lineName: name,
      startName: start,
      middleName: middle?.isNotEmpty == true ? middle : null,
      endName: end,
      direction: direction,
      status: DriverRouteRequestStatus.pending,
      requestedBy: driver,
    );
  }

  Future<void> cancelRequest({required String requestId}) async {
    final request = await getById(requestId);
    if (request == null) {
      throw const DriverRouteRequestException(
        'طلب المسار غير موجود.',
        code: 'not-found',
      );
    }
    if (!request.isPending) {
      throw const DriverRouteRequestException(
        'لا يمكن إلغاء طلب غير معلّق.',
        code: 'not-pending',
      );
    }

    await _col.doc(request.id).update({
      'status': DriverRouteRequestStatus.cancelled.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRequest({
    required String requestId,
    required String adminId,
    String? reason,
  }) async {
    final request = await getById(requestId);
    if (request == null) {
      throw const DriverRouteRequestException(
        'طلب المسار غير موجود.',
        code: 'not-found',
      );
    }

    final reviewer = adminId.trim();
    if (reviewer.isEmpty) {
      throw const DriverRouteRequestException(
        'معرف الأدمن مطلوب.',
        code: 'invalid-admin',
      );
    }

    final cleanReason = reason?.trim();
    await _col.doc(request.id).update({
      'status': DriverRouteRequestStatus.rejected.firestoreValue,
      'reviewedBy': reviewer,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (cleanReason != null && cleanReason.isNotEmpty)
        'reviewNote': cleanReason
      else
        'reviewNote': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRequest({
    required String requestId,
    required String adminId,
    required String routeId,
  }) async {
    final request = await getById(requestId);
    if (request == null) {
      throw const DriverRouteRequestException(
        'طلب المسار غير موجود.',
        code: 'not-found',
      );
    }
    if (!request.isPending) {
      throw const DriverRouteRequestException(
        'طلب المسار ليس بانتظار المراجعة.',
        code: 'not-pending',
      );
    }

    final reviewer = adminId.trim();
    final route = routeId.trim();
    if (reviewer.isEmpty || route.isEmpty) {
      throw const DriverRouteRequestException(
        'بيانات اعتماد طلب المسار غير مكتملة.',
        code: 'invalid-approval',
      );
    }

    final ref = _col.doc(request.id);
    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(ref);
      final routeSnap = await tx.get(_db.collection('plannedRoutes').doc(route));

      if (!requestSnap.exists || requestSnap.data() == null) {
        throw const DriverRouteRequestException(
          'طلب المسار غير موجود.',
          code: 'not-found',
        );
      }
      if (!routeSnap.exists || routeSnap.data() == null) {
        throw const DriverRouteRequestException(
          'المسار الناتج عن الطلب غير موجود.',
          code: 'route-not-found',
        );
      }

      final current = DriverRouteRequest.fromDoc(
        requestSnap.id,
        requestSnap.data()!,
      );
      if (!current.isPending) {
        throw const DriverRouteRequestException(
          'طلب المسار ليس بانتظار المراجعة.',
          code: 'not-pending',
        );
      }

      final plannedRoute = PlannedRoute.fromDoc(
        routeSnap.id,
        routeSnap.data()!,
      );
      if (!plannedRoute.isApproved || plannedRoute.points.length < 2) {
        throw const DriverRouteRequestException(
          'المسار الناتج عن الطلب غير معتمد أو غير مكتمل.',
          code: 'route-not-approved',
        );
      }
      if (plannedRoute.direction != current.direction) {
        throw const DriverRouteRequestException(
          'اتجاه المسار الناتج لا يطابق اتجاه الطلب.',
          code: 'direction-mismatch',
        );
      }
      if (plannedRoute.lineName.trim() != current.lineName.trim()) {
        throw const DriverRouteRequestException(
          'اسم الخط في المسار لا يطابق الطلب.',
          code: 'line-name-mismatch',
        );
      }
      if (current.lineId?.trim().isNotEmpty == true &&
          plannedRoute.lineId?.trim() != current.lineId!.trim()) {
        throw const DriverRouteRequestException(
          'الخط المرتبط بالمسار لا يطابق طلب السائق.',
          code: 'line-mismatch',
        );
      }

      tx.update(ref, {
        'status': DriverRouteRequestStatus.approved.firestoreValue,
        'routeId': plannedRoute.id,
        if (plannedRoute.lineId?.trim().isNotEmpty == true)
          'lineId': plannedRoute.lineId!.trim(),
        'reviewedBy': reviewer,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewNote': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  bool _sameRequest(
    DriverRouteRequest request, {
    required String lineName,
    required String startName,
    required String? middleName,
    required String endName,
    required RouteDirection direction,
    required String? lineId,
  }) {
    String clean(String value) => value.trim();
    return clean(request.lineName) == lineName &&
        clean(request.startName) == startName &&
        clean(request.endName) == endName &&
        clean(request.middleName ?? '') == clean(middleName ?? '') &&
        request.direction == direction &&
        clean(request.lineId ?? '') == clean(lineId ?? '');
  }

  DateTime _timestampOf(DriverRouteRequest request) {
    return request.reviewedAt ??
        request.requestedAt ??
        request.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class DriverRouteRequestException implements Exception {
  final String message;
  final String? code;

  const DriverRouteRequestException(this.message, {this.code});

  @override
  String toString() => message;
}
