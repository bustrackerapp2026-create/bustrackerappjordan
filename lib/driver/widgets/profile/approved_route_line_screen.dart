import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/driver_line_assignment.dart';
import '../../../models/planned_route.dart';
import '../../../models/transit_line.dart';
import '../../../services/driver_line_assignment_service.dart';

/// شاشة مستقلة تعرض حالة تعيين المسار للسائق فقط.
///
/// هذه المرحلة لا تحتوي على البحث أو إرسال طلب جديد.
/// الهدف هو تثبيت قراءة الحالة الحالية من Firebase: معتمد / قيد المراجعة / لا يوجد.
class ApprovedRouteLineScreen extends StatefulWidget {
  const ApprovedRouteLineScreen({super.key});

  @override
  State<ApprovedRouteLineScreen> createState() =>
      _ApprovedRouteLineScreenState();
}

class _ApprovedRouteLineScreenState extends State<ApprovedRouteLineScreen> {
  final DriverLineAssignmentService _assignments =
      DriverLineAssignmentService();

  bool _loading = true;
  String? _error;

  DriverLineAssignment? _approved;
  DriverLineAssignment? _pending;

  TransitLine? _approvedLine;
  TransitLine? _pendingLine;

  PlannedRoute? _approvedRoute;
  PlannedRoute? _pendingRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<TransitLine?> _loadLine(String lineId) async {
    final id = lineId.trim();
    if (id.isEmpty) return null;

    final snap =
        await FirebaseFirestore.instance.collection('transitLines').doc(id).get();

    if (!snap.exists || snap.data() == null) return null;
    return TransitLine.fromDoc(snap.id, snap.data()!);
  }

  Future<PlannedRoute?> _loadRoute(String routeId) async {
    final id = routeId.trim();
    if (id.isEmpty) return null;

    final snap =
        await FirebaseFirestore.instance.collection('plannedRoutes').doc(id).get();

    if (!snap.exists || snap.data() == null) return null;
    return PlannedRoute.fromDoc(snap.id, snap.data()!);
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.userId?.trim();
    final busNumber = auth.userData?.busNumber?.trim() ?? '';

    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحديد حساب السائق الحالي.';
        _approved = null;
        _pending = null;
        _approvedLine = null;
        _pendingLine = null;
        _approvedRoute = null;
        _pendingRoute = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // التعيين التشغيلي مرتبط بالمركبة، وليس بالسائق الذي أنشأ الطلب.
      // لذلك يجب أن يرى أي سائق مسجل على نفس المركبة المسار المعتمد نفسه.
      DriverLineAssignment? approved;

      if (busNumber.isNotEmpty) {
        final vehicleApproved =
            await _assignments.getApprovedAssignmentsForVehicle(
          busNumber,
          limit: 200,
        );
        if (vehicleApproved.isNotEmpty) {
          approved = vehicleApproved.first;
        }
      }

      // توافق رجعي مع السجلات القديمة التي لا تحتوي busNumber.
      // نستخدم بحث السائق فقط عندما لا يتوفر تعيين تشغيلي على المركبة.
      if (approved == null) {
        final driverApproved =
            await _assignments.getApprovedAssignmentsForDriver(uid, limit: 200);
        if (busNumber.isNotEmpty) {
          for (final item in driverApproved) {
            if (item.busNumber.trim().isEmpty) {
              approved = item;
              break;
            }
          }
        } else if (driverApproved.isNotEmpty) {
          approved = driverApproved.first;
        }
      }

      DriverLineAssignment? pending;
      if (busNumber.isNotEmpty) {
        final vehiclePending =
            await _assignments.getPendingForVehicle(busNumber, limit: 200);
        if (vehiclePending != null) {
          pending = vehiclePending;
        }
      }

      // إذا لم يوجد طلب على المركبة، نحاول طلب السائق نفسه فقط للتوافق
      // مع البيانات القديمة.
      if (pending == null) {
        final driverPending = await _assignments.getPendingForDriver(uid);
        if (busNumber.isNotEmpty) {
          if (driverPending?.busNumber.trim().isEmpty == true) {
            pending = driverPending;
          }
        } else {
          pending = driverPending;
        }
      }

      TransitLine? approvedLine;
      PlannedRoute? approvedRoute;

      if (approved != null) {
        approvedLine = await _loadLine(approved.lineId);
        approvedRoute = await _loadRoute(approved.routeId);
      }

      TransitLine? pendingLine;
      PlannedRoute? pendingRoute;

      if (pending != null) {
        pendingLine = await _loadLine(pending.lineId);
        pendingRoute = await _loadRoute(pending.routeId);
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _approved = approved;
        _approvedLine = approvedLine;
        _approvedRoute = approvedRoute;
        _pending = pending;
        _pendingLine = pendingLine;
        _pendingRoute = pendingRoute;
      });
    } catch (e, stackTrace) {
      debugPrint('ApprovedRouteLineScreen load error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل حالة تعيين المسار الحالية.';
        _approved = null;
        _pending = null;
        _approvedLine = null;
        _pendingLine = null;
        _approvedRoute = null;
        _pendingRoute = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasApproved = _approved != null;
    final hasPending = _pending != null;
    final userData = context.read<AuthProvider>().userData;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خط المسار المعتمد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _MessageCard(
                        icon: Icons.error_outline_rounded,
                        title: 'تعذر تحميل البيانات',
                        message: _error!,
                        actionLabel: 'إعادة المحاولة',
                        onAction: _load,
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (hasApproved)
                      _AssignmentCard(
                        title: 'المسار المعتمد الحالي',
                        statusLabel: 'معتمد',
                        statusColor: const Color(0xFF2E7D32),
                        icon: Icons.check_circle_rounded,
                        assignment: _approved!,
                        line: _approvedLine,
                        route: _approvedRoute,
                        driverName: userData?.displayName ?? 'غير متوفر',
                        driverPhone: userData?.displayPhone ?? 'غير محدد',
                        vehicleNumber: userData?.busNumber?.trim() ?? '',
                      )
                    else if (hasPending)
                      _AssignmentCard(
                        title: 'طلب المسار الحالي',
                        statusLabel: 'قيد المراجعة',
                        statusColor: const Color(0xFFEF6C00),
                        icon: Icons.hourglass_top_rounded,
                        assignment: _pending!,
                        line: _pendingLine,
                        route: _pendingRoute,
                        driverName: userData?.displayName ?? 'غير متوفر',
                        driverPhone: userData?.displayPhone ?? 'غير محدد',
                        vehicleNumber: userData?.busNumber?.trim() ?? '',
                      )
                    else
                      const _EmptyState(),

                    if (hasApproved && hasPending) ...[
                      const SizedBox(height: 12),
                      _AssignmentCard(
                        title: 'يوجد طلب آخر قيد المراجعة',
                        statusLabel: 'قيد المراجعة',
                        statusColor: const Color(0xFFEF6C00),
                        icon: Icons.info_outline_rounded,
                        assignment: _pending!,
                        line: _pendingLine,
                        route: _pendingRoute,
                        driverName: userData?.displayName ?? 'غير متوفر',
                        driverPhone: userData?.displayPhone ?? 'غير محدد',
                        vehicleNumber: userData?.busNumber?.trim() ?? '',
                      ),
                    ],

                    const SizedBox(height: 12),
                    const _StageNote(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.icon,
    required this.assignment,
    required this.line,
    required this.route,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleNumber,
  });

  final String title;
  final String statusLabel;
  final Color statusColor;
  final IconData icon;
  final DriverLineAssignment assignment;
  final TransitLine? line;
  final PlannedRoute? route;
  final String driverName;
  final String driverPhone;
  final String vehicleNumber;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final lineName = line?.name.trim().isNotEmpty == true
        ? line!.name.trim()
        : (route?.lineName.trim().isNotEmpty == true
            ? route!.lineName.trim()
            : 'غير متوفر');

    final direction = route?.direction.labelAr ?? 'غير متوفر';
    final startName = line?.startName.trim().isNotEmpty == true
        ? line!.startName.trim()
        : null;
    final endName = line?.endName.trim().isNotEmpty == true
        ? line!.endName.trim()
        : null;

    final displayedVehicleNumber =
        vehicleNumber.isNotEmpty ? vehicleNumber : assignment.busNumber.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(
                label: statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.route_rounded,
            label: 'الخط',
            value: lineName,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.swap_horiz_rounded,
            label: 'الاتجاه',
            value: direction,
          ),
          if (startName != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.trip_origin_rounded,
              label: 'البداية',
              value: startName,
            ),
          ],
          if (endName != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'النهاية',
              value: endName,
            ),
          ],
          const SizedBox(height: 18),
          _InfoRow(
            icon: Icons.directions_bus_outlined,
            label: 'رقم المركبة',
            value: displayedVehicleNumber.isNotEmpty
                ? displayedVehicleNumber
                : 'غير محدد',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'اسم السائق',
            value: driverName,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'رقم الهاتف',
            value: driverPhone,
          ),
          if (route != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.straighten_rounded,
              label: 'طول المسار',
              value: _formatDistance(route!.distanceMeters),
            ),
          ],
          if (route == null) ...[
            const SizedBox(height: 12),
            _MessageCard(
              compact: true,
              icon: Icons.warning_amber_rounded,
              title: 'تفاصيل المسار غير متاحة',
              message:
                  'تم العثور على حالة التعيين، لكن مستند المسار المرتبط لم يتم تحميله.',
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDistance(double? meters) {
    if (meters == null || meters.isNaN || meters.isInfinite) {
      return 'غير متوفر';
    }

    if (meters < 1000) {
      return '${meters.round()} م';
    }

    final km = meters / 1000;
    return '${km.toStringAsFixed(km >= 10 ? 1 : 2)} كم';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.route_outlined,
            size: 54,
            color: scheme.onSurface.withValues(alpha: 0.42),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا يوجد مسار معتمد حاليًا',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'لم يتم اعتماد أي مسار لهذه المركبة حتى الآن.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageNote extends StatelessWidget {
  const _StageNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(
      'هذه المرحلة تعرض حالة التعيين الحالية فقط. البحث وإرسال طلب مسار جديد غير مفعّلين بعد.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: scheme.onSurface.withValues(alpha: 0.52),
        height: 1.35,
      ),
    );
  }
}
