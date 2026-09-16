import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/driver_line_assignment.dart';
import '../../../models/planned_route.dart';
import '../../../models/transit_line.dart';
import '../../../services/driver_line_assignment_service.dart';

/// الشاشة المستقلة الخاصة بميزة "خط المسار المعتمد".
///
/// هذه المرحلة تربط واجهة العرض ببيانات التعيين الفعلية فقط،
/// دون فتح البحث أو إنشاء طلبات جديدة.
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
  TransitLine? _line;
  PlannedRoute? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().userId?.trim();
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحديد حساب السائق.';
        _approved = null;
        _pending = null;
        _line = null;
        _route = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final approved = await _assignments.getApprovedForDriver(uid);
      final pending = approved == null
          ? await _assignments.getPendingForDriver(uid)
          : null;

      TransitLine? line;
      PlannedRoute? route;
      final active = approved ?? pending;
      if (active != null) {
        if (approved != null) {
          line = await _assignments.getApprovedLineForDriver(uid);
        }
        route = await _loadRoute(active.routeId);
        if (line == null && active.lineId.trim().isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('transitLines')
              .doc(active.lineId.trim())
              .get();
          if (snap.exists && snap.data() != null) {
            line = TransitLine.fromDoc(snap.id, snap.data()!);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _approved = approved;
        _pending = pending;
        _line = line;
        _route = route;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات المسار المعتمد.';
        _approved = null;
        _pending = null;
        _line = null;
        _route = null;
      });
    }
  }

  Future<PlannedRoute?> _loadRoute(String routeId) async {
    final id = routeId.trim();
    if (id.isEmpty) return null;
    final snap =
        await FirebaseFirestore.instance.collection('plannedRoutes').doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return PlannedRoute.fromDoc(snap.id, snap.data()!);
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    const _IntroCard(),
                    const SizedBox(height: 14),
                    if (_error != null) ...[
                      _ErrorCard(message: _error!, onRetry: _load),
                      const SizedBox(height: 14),
                    ],
                    _StatusCard(
                      approved: _approved,
                      pending: _pending,
                    ),
                    const SizedBox(height: 14),
                    _RouteDetailsCard(
                      approved: _approved,
                      pending: _pending,
                      line: _line,
                      route: _route,
                    ),
                    const SizedBox(height: 14),
                    _RequestStatusCard(
                      approved: _approved,
                      pending: _pending,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'البحث عن الخطوط المعتمدة سيتم ربطه في المرحلة التالية.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search_rounded),
                        label: const Text(
                          'البحث عن خط معتمد',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.11),
            scheme.surface,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'خط المسار المعتمد',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'مكان مخصص لعرض الخط المعتمد ومتابعة طلب تعيين المسار للسائق.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'تعذر التحميل',
      icon: Icons.error_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.approved,
    required this.pending,
  });

  final DriverLineAssignment? approved;
  final DriverLineAssignment? pending;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final IconData icon;
    final String title;
    final String subtitle;

    if (approved != null) {
      accent = Colors.green;
      icon = Icons.check_circle_rounded;
      title = 'تم تعيين مسار معتمد';
      subtitle = 'يمكنك العمل على هذا المسار بعد التحقق من القرب عند الاتصال.';
    } else if (pending != null) {
      accent = Colors.orange;
      icon = Icons.hourglass_top_rounded;
      title = 'طلب التعيين قيد المراجعة';
      subtitle = 'بانتظار موافقة الأدمن على المسار الذي اخترته.';
    } else {
      accent = Colors.blueGrey;
      icon = Icons.route_outlined;
      title = 'لا يوجد مسار معتمد';
      subtitle = 'اختر مسارًا معتمدًا من البحث عندما يصبح متاحًا في المرحلة التالية.';
    }

    return _SectionCard(
      title: 'الحالة الحالية',
      icon: Icons.verified_rounded,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetailsCard extends StatelessWidget {
  const _RouteDetailsCard({
    required this.approved,
    required this.pending,
    required this.line,
    required this.route,
  });

  final DriverLineAssignment? approved;
  final DriverLineAssignment? pending;
  final TransitLine? line;
  final PlannedRoute? route;

  @override
  Widget build(BuildContext context) {
    final active = approved ?? pending;
    final lineName = line?.name.trim().isNotEmpty == true
        ? line!.name.trim()
        : (route?.lineName.trim().isNotEmpty == true
            ? route!.lineName.trim()
            : 'غير محدد');
    final startName = line?.startName.trim().isNotEmpty == true
        ? line!.startName.trim()
        : 'غير محددة';
    final endName = line?.endName.trim().isNotEmpty == true
        ? line!.endName.trim()
        : 'غير محددة';
    final direction = route?.direction.labelAr ?? 'غير محدد';
    final approvalLabel = active == null
        ? '—'
        : (approved != null
            ? 'معتمد'
            : (pending != null ? 'قيد المراجعة' : '—'));
    final approvalColor = approved != null
        ? Colors.green
        : (pending != null ? Colors.orange : null);

    return _SectionCard(
      title: 'معلومات الخط',
      icon: Icons.alt_route_rounded,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.drive_file_rename_outline_rounded,
            label: 'اسم الخط',
            value: lineName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.trip_origin_rounded,
            label: 'نقطة البداية',
            value: startName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: 'نقطة النهاية',
            value: endName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.swap_horiz_rounded,
            label: 'الاتجاه',
            value: direction,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.shield_rounded,
            label: 'حالة الاعتماد',
            value: approvalLabel,
            valueColor: approvalColor,
          ),
        ],
      ),
    );
  }
}

class _RequestStatusCard extends StatelessWidget {
  const _RequestStatusCard({
    required this.approved,
    required this.pending,
  });

  final DriverLineAssignment? approved;
  final DriverLineAssignment? pending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color boxColor;
    final Color iconColor;
    final String message;

    if (approved != null) {
      boxColor = Colors.green.withValues(alpha: 0.08);
      iconColor = Colors.green;
      message =
          'لديك مسار معتمد. طلبات التغيير لاحقًا ستظهر هنا بعد تفعيلها.';
    } else if (pending != null) {
      boxColor = Colors.orange.withValues(alpha: 0.08);
      iconColor = Colors.orange;
      message =
          'طلب تعيين المسار قيد المراجعة لدى الأدمن. لن يتم تفعيل المسار قبل الموافقة.';
    } else {
      boxColor = scheme.surfaceContainerHighest.withValues(alpha: 0.45);
      iconColor = scheme.onSurface.withValues(alpha: 0.55);
      message =
          'لا يوجد طلب تعيين حالي. البحث وطلب مسار معتمد سيُربطان في المرحلة التالية.';
    }

    return _SectionCard(
      title: 'حالة الطلب',
      icon: Icons.pending_actions_rounded,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: iconColor, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: scheme.onSurface.withValues(alpha: 0.76),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            child,
          ],
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
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
