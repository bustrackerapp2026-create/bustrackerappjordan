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

/// حالة اعتماد مسار الخط
enum PlannedRouteStatus {
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
        return 'معتمد';
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

/// مسار خط مخزّن (ذهاب أو إياب) — يظهر للركاب بعد الاعتماد.
class PlannedRoute {
  final String id;
  final String driverId;
  final String lineName;
  final RouteDirection direction;
  final List<RoutePoint> points;
  final PlannedRouteStatus status;
  final bool editRequestPending;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? distanceMeters;
  final String? notes;

  const PlannedRoute({
    required this.id,
    required this.driverId,
    required this.lineName,
    required this.direction,
    required this.points,
    this.status = PlannedRouteStatus.pending,
    this.editRequestPending = false,
    this.createdAt,
    this.updatedAt,
    this.distanceMeters,
    this.notes,
  });

  bool get isApproved => status == PlannedRouteStatus.approved;
  bool get canEdit =>
      status == PlannedRouteStatus.rejected ||
      (status == PlannedRouteStatus.pending && !editRequestPending);
  bool get isLocked =>
      status == PlannedRouteStatus.approved && !editRequestPending;

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'lineName': lineName,
      'direction': direction.firestoreValue,
      'points': points.map((p) => p.toMap()).toList(),
      'status': status.firestoreValue,
      'editRequestPending': editRequestPending,
      'distanceMeters': distanceMeters,
      if (notes != null) 'notes': notes,
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

    return PlannedRoute(
      id: id,
      driverId: data['driverId']?.toString() ?? '',
      lineName: data['lineName']?.toString() ?? '',
      direction: RouteDirectionX.fromString(data['direction']?.toString()),
      points: points,
      status: PlannedRouteStatusX.fromString(data['status']?.toString()),
      editRequestPending: data['editRequestPending'] == true,
      createdAt: created,
      updatedAt: updated,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      notes: data['notes']?.toString(),
    );
  }
}
