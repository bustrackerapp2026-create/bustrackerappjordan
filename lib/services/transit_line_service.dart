import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/arabic_search.dart';
import '../models/transit_line.dart';

class TransitLineServiceException implements Exception {
  final String message;
  final String? code;

  const TransitLineServiceException(this.message, {this.code});

  @override
  String toString() => message;
}

/// إدارة الخطوط التشغيلية الرسمية بشكل مستقل عن المسارات الجغرافية.
class TransitLineService {
  TransitLineService._();
  static final TransitLineService instance = TransitLineService._();
  factory TransitLineService() => instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('transitLines');

  Future<TransitLine?> getById(String lineId) async {
    if (lineId.trim().isEmpty) return null;
    final snap = await _col.doc(lineId.trim()).get();
    if (!snap.exists || snap.data() == null) return null;
    return TransitLine.fromDoc(snap.id, snap.data()!);
  }

  Future<TransitLine?> findByNormalizedName(String name) async {
    final normalized = ArabicSearch.normalize(name);
    if (normalized.isEmpty) return null;

    final snap = await _col
        .where('normalizedName', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TransitLine.fromDoc(snap.docs.first.id, snap.docs.first.data());
  }

  Future<TransitLine> proposeLine({
    required String driverId,
    required String name,
    required String startName,
    required String endName,
    String? middleName,
    List<String> passingPlaces = const [],
    List<String> aliases = const [],
  }) async {
    final id = driverId.trim();
    final displayName = name.trim();
    final start = startName.trim();
    final end = endName.trim();
    final middle = middleName?.trim();

    if (id.isEmpty) {
      throw const TransitLineServiceException('معرف السائق مطلوب.');
    }
    if (displayName.isEmpty) {
      throw const TransitLineServiceException('اسم الخط مطلوب.');
    }
    if (start.isEmpty) {
      throw const TransitLineServiceException('بداية الخط مطلوبة.');
    }
    if (end.isEmpty) {
      throw const TransitLineServiceException('نهاية الخط مطلوبة.');
    }

    final normalized = ArabicSearch.normalize(displayName);
    if (normalized.isEmpty) {
      throw const TransitLineServiceException('اسم الخط غير صالح.');
    }

    final existing = await findByNormalizedName(displayName);
    if (existing != null) {
      throw TransitLineServiceException(
        existing.isApproved
            ? 'هذا الخط موجود ومعتمد بالفعل.'
            : 'يوجد طلب مسبق لهذا الخط بحالة ${existing.status.firestoreValue}.',
        code: 'line-exists',
      );
    }

    final docRef = _col.doc();
    final cleanPassingPlaces = passingPlaces
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final cleanAliases = aliases
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    await docRef.set({
      'name': displayName,
      'normalizedName': normalized,
      'startName': start,
      if (middle != null && middle.isNotEmpty) 'middleName': middle,
      'endName': end,
      'passingPlaces': cleanPassingPlaces,
      'aliases': cleanAliases,
      'status': TransitLineStatus.pending.firestoreValue,
      'proposedBy': id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return TransitLine(
      id: docRef.id,
      name: displayName,
      normalizedName: normalized,
      startName: start,
      middleName: middle?.isNotEmpty == true ? middle : null,
      endName: end,
      passingPlaces: cleanPassingPlaces,
      aliases: cleanAliases,
      status: TransitLineStatus.pending,
      proposedBy: id,
    );
  }

  Future<List<TransitLine>> listApproved({int limit = 100}) async {
    final snap = await _col
        .where('status', isEqualTo: TransitLineStatus.approved.firestoreValue)
        .limit(limit.clamp(1, 200))
        .get();

    final lines = snap.docs
        .map((doc) => TransitLine.fromDoc(doc.id, doc.data()))
        .toList();
    lines.sort((a, b) => a.name.compareTo(b.name));
    return lines;
  }

  Stream<List<TransitLine>> watchApproved() {
    return _col
        .where('status', isEqualTo: TransitLineStatus.approved.firestoreValue)
        .snapshots()
        .map((snap) {
      final lines = snap.docs
          .map((doc) => TransitLine.fromDoc(doc.id, doc.data()))
          .toList();
      lines.sort((a, b) => a.name.compareTo(b.name));
      return lines;
    });
  }

  Future<List<TransitLine>> searchApproved(
    String query, {
    int limit = 50,
  }) async {
    final all = await listApproved(limit: limit.clamp(1, 200));
    final q = query.trim();
    if (q.isEmpty) return all.take(limit.clamp(1, 200)).toList();

    return ArabicSearch.rankByScore(
      query: q,
      items: all,
      lineNameOf: (line) => line.name,
      aliasesOf: (line) => line.aliases,
    ).take(limit.clamp(1, 200)).toList();
  }

  Stream<List<TransitLine>> watchPendingProposals() {
    return _col
        .where('status', isEqualTo: TransitLineStatus.pending.firestoreValue)
        .snapshots()
        .map((snap) {
      final lines = snap.docs
          .map((doc) => TransitLine.fromDoc(doc.id, doc.data()))
          .toList();
      lines.sort((a, b) => a.name.compareTo(b.name));
      return lines;
    });
  }

  Stream<List<TransitLine>> watchDriverProposals(String driverId) {
    final id = driverId.trim();
    if (id.isEmpty) return const Stream.empty();

    return _col.where('proposedBy', isEqualTo: id).snapshots().map((snap) {
      final lines = snap.docs
          .map((doc) => TransitLine.fromDoc(doc.id, doc.data()))
          .toList();
      lines.sort((a, b) => a.name.compareTo(b.name));
      return lines;
    });
  }

  Future<void> approveLine({
    required String lineId,
    required String adminId,
  }) async {
    final id = lineId.trim();
    final reviewer = adminId.trim();
    if (id.isEmpty || reviewer.isEmpty) {
      throw const TransitLineServiceException('بيانات اعتماد الخط غير مكتملة.');
    }

    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw const TransitLineServiceException('الخط غير موجود.', code: 'not-found');
    }

    final current = TransitLine.fromDoc(snap.id, snap.data()!);
    if (current.status == TransitLineStatus.approved) return;
    if (current.status == TransitLineStatus.archived) {
      throw const TransitLineServiceException('لا يمكن اعتماد خط مؤرشف.');
    }

    await ref.update({
      'status': TransitLineStatus.approved.firestoreValue,
      'approvedBy': reviewer,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectLine({
    required String lineId,
    required String adminId,
    String? reason,
  }) async {
    final id = lineId.trim();
    final reviewer = adminId.trim();
    if (id.isEmpty || reviewer.isEmpty) {
      throw const TransitLineServiceException('بيانات رفض الخط غير مكتملة.');
    }

    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      throw const TransitLineServiceException('الخط غير موجود.', code: 'not-found');
    }

    final cleanReason = reason?.trim();
    await ref.update({
      'status': TransitLineStatus.rejected.firestoreValue,
      'approvedBy': FieldValue.delete(),
      'approvedAt': FieldValue.delete(),
      if (cleanReason != null && cleanReason.isNotEmpty)
        'rejectionReason': cleanReason
      else
        'rejectionReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveLine({
    required String lineId,
    required String adminId,
  }) async {
    if (lineId.trim().isEmpty || adminId.trim().isEmpty) {
      throw const TransitLineServiceException('بيانات أرشفة الخط غير مكتملة.');
    }

    await _col.doc(lineId.trim()).update({
      'status': TransitLineStatus.archived.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
