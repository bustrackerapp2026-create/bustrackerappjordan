import 'package:cloud_firestore/cloud_firestore.dart';

import 'route_point.dart';

/// اتجاه مسار الخط المخزّن
enum RouteDirection {
  /// من بداية الخط إلى نهايته
  outbound,

  /// من النهاية إلى البداية (العودة)
  returnTrip,
}

extension RouteDirectionX on RouteDirection {
  String get firestoreValue =>
      this == RouteDirection.outbound ? 'outbound' : 'return';

  String get labelAr =>
      this == RouteDirection.outbound ? 'ذهاب' : 'إياب';

  static RouteDirection fromString(String? v) {
    if (v == 'return' || v == 'returnTrip') return RouteDirection.returnTrip;
    return RouteDirection.outbound;
  }
}

/// حالة مسار الخط
enum PlannedRouteStatus {
  /// بانتظار موافقة على تعديل (نادر بعد التحويل للحفظ التلقائي)
  pending,
  approved,
  rejected,
}

extension PlannedRouteStatusX on PlannedRouteStatus {
  String get firestoreValue {
    switch (this) {
      case PlannedRouteStatus.pending:
        return 'pending';
      case PlannedRouteStatus.approved:
        return 'approved';
      case PlannedRouteStatus.rejected:
        return 'rejected';
    }
  }

  String get labelAr {
    switch (this) {
      case PlannedRouteStatus.pending:
        return 'بانتظار الموافقة';
      case PlannedRouteStatus.approved:
        return 'مخزّن';
      case PlannedRouteStatus.rejected:
        return 'مرفوض';
    }
  }

  static PlannedRouteStatus fromString(String? v) {
    switch (v) {
      case 'approved':
        return PlannedRouteStatus.approved;
      case 'rejected':
        return PlannedRouteStatus.rejected;
      default:
        return PlannedRouteStatus.pending;
    }
  }
}

/// مصدر إنشاء المسار
enum RouteSource {
  driver,
  admin,
}

extension RouteSourceX on RouteSource {
  String get firestoreValue => this == RouteSource.admin ? 'admin' : 'driver';

  static RouteSource fromString(String? v) {
    if (v == 'admin') return RouteSource.admin;
    return RouteSource.driver;
  }
}

/// مسار خط مشترك (ذهاب أو إياب) — يُخزَّن مرة واحدة لكل خط+اتجاه ويظهر للركاب فوراً.
class PlannedRoute {
  final String id;
  /// من سجّل المسار أول مرة (سائق أو أدمن)
  final String createdBy;
  final String lineName;
  final RouteDirection direction;
  final List<RoutePoint> points;
  final PlannedRouteStatus status;
  final bool editRequestPending;
  final String? editRequestReason;
  final String? editRequestedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? distanceMeters;
  final String? notes;
  final RouteSource source;

  /// بعد موافقة الأدمن على طلب التعديل يُسمح بإعادة التسجيل
  final bool reRecordAllowed;

  /// مفاتيح بحث عربية مطبّعة (تُخزَّن في Firestore)
  final List<String> searchKeys;

  /// أسماء بديلة للخط (مثال: الزرقاء — عمان)
  final List<String> aliases;

  const PlannedRoute({
    required this.id,
    required this.createdBy,
    required this.lineName,
    required this.direction,
    required this.points,
    this.status = PlannedRouteStatus.approved,
    this.editRequestPending = false,
    this.editRequestReason,
    this.editRequestedBy,
    this.createdAt,
    this.updatedAt,
    this.distanceMeters,
    this.notes,
    this.source = RouteSource.driver,
    this.reRecordAllowed = false,
    this.searchKeys = const [],
    this.aliases = const [],
  });

  bool get isApproved => status == PlannedRouteStatus.approved;

  /// مقفول: موجود ومعتمد ولا يُسمح بإعادة التسجيل
  bool get isLocked =>
      status == PlannedRouteStatus.approved &&
      !reRecordAllowed &&
      points.length >= 2;

  bool get canReRecord =>
      reRecordAllowed ||
      status == PlannedRouteStatus.rejected ||
      (status == PlannedRouteStatus.pending && points.isEmpty);

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'driverId': createdBy, // توافق خلفي
      'lineName': lineName,
      'direction': direction.firestoreValue,
      'points': points.map((p) => p.toMap()).toList(),
      'status': status.firestoreValue,
      'editRequestPending': editRequestPending,
      if (editRequestReason != null) 'editRequestReason': editRequestReason,
      if (editRequestedBy != null) 'editRequestedBy': editRequestedBy,
      'distanceMeters': distanceMeters,
      if (notes != null) 'notes': notes,
      'source': source.firestoreValue,
      'reRecordAllowed': reRecordAllowed,
      'searchKeys': searchKeys,
      'aliases': aliases,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PlannedRoute.fromDoc(String id, Map<String, dynamic> data) {
    final rawPoints = data['points'];
    final points = <RoutePoint>[];
    if (rawPoints is List) {
      for (final r in rawPoints) {
        final p = RoutePoint.parse(r);
        if (p != null) points.add(p);
      }
    }

    DateTime? created;
    final c = data['createdAt'];
    if (c is Timestamp) created = c.toDate();

    DateTime? updated;
    final u = data['updatedAt'];
    if (u is Timestamp) updated = u.toDate();

    final createdBy = (data['createdBy'] ?? data['driverId'])?.toString() ?? '';

    List<String> readStringList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return PlannedRoute(
      id: id,
      createdBy: createdBy,
      lineName: data['lineName']?.toString() ?? '',
      direction: RouteDirectionX.fromString(data['direction']?.toString()),
      points: points,
      status: PlannedRouteStatusX.fromString(data['status']?.toString()),
      editRequestPending: data['editRequestPending'] == true,
      editRequestReason: data['editRequestReason']?.toString(),
      editRequestedBy: data['editRequestedBy']?.toString(),
      createdAt: created,
      updatedAt: updated,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      notes: data['notes']?.toString(),
      source: RouteSourceX.fromString(data['source']?.toString()),
      reRecordAllowed: data['reRecordAllowed'] == true,
      searchKeys: readStringList(data['searchKeys']),
      aliases: readStringList(data['aliases']),
    );
  }

  /// توافق مع الكود القديم الذي يستخدم driverId
  String get driverId => createdBy;
}
