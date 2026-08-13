import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/planned_route.dart';
import '../../../services/route_plan_service.dart';

/// تبويب الأدمن: اعتماد مسارات الخطوط المخططة وطلبات التعديل.
class PendingRoutesTab extends StatefulWidget {
  const PendingRoutesTab({super.key});

  @override
  State<PendingRoutesTab> createState() => _PendingRoutesTabState();
}

class _PendingRoutesTabState extends State<PendingRoutesTab>
    with SingleTickerProviderStateMixin {
  final RoutePlanService _service = RoutePlanService();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _driverName(String driverId) async {
    if (driverId.isEmpty) return '—';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();
      final name = doc.data()?['fullName']?.toString().trim();
      return (name != null && name.isNotEmpty) ? name : '—';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _approve(PlannedRoute r) async {
    try {
      await _service.approveRoute(r.id);
      _snack('تم اعتماد مسار ${r.direction.labelAr} · ${r.lineName}');
    } catch (e) {
      _snack('فشل الاعتماد: $e', error: true);
    }
  }

  Future<void> _reject(PlannedRoute r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('رفض المسار'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض (اختياري)',
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await _service.rejectRoute(
        r.id,
        reason: reason.isEmpty ? null : reason,
      );
      _snack('تم رفض مسار ${r.direction.labelAr}');
    } catch (e) {
      _snack('فشل الرفض: $e', error: true);
    }
  }

  Future<void> _approveEdit(PlannedRoute r) async {
    try {
      await _service.approveEditRequest(r.id);
      _snack(
        'تمت الموافقة على طلب التعديل — يمكن للسائق إعادة التسجيل',
      );
    } catch (e) {
      _snack('فشل: $e', error: true);
    }
  }

  Future<void> _denyEdit(PlannedRoute r) async {
    try {
      // إبقاء المسار معتمداً وإلغاء طلب التعديل فقط
      await FirebaseFirestore.instance
          .collection('plannedRoutes')
          .doc(r.id)
          .update({
        'editRequestPending': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('تم رفض طلب التعديل');
    } catch (e) {
      _snack('فشل: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'مسارات جديدة'),
              Tab(text: 'طلبات تعديل'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _RoutesList(
                stream: _service.watchPendingRoutes(),
                emptyTitle: 'لا توجد مسارات بانتظار الاعتماد',
                emptyHint: 'عندما يسجّل سائق مساراً جديداً سيظهر هنا.',
                driverNameOf: _driverName,
                primaryLabel: 'اعتماد',
                primaryIcon: Icons.check_rounded,
                onPrimary: _approve,
                secondaryLabel: 'رفض',
                secondaryIcon: Icons.close_rounded,
                onSecondary: _reject,
                secondaryIsDestructive: true,
              ),
              _RoutesList(
                stream: _service.watchEditRequests(),
                emptyTitle: 'لا توجد طلبات تعديل',
                emptyHint: 'طلبات تعديل المسارات المعتمدة تظهر هنا.',
                driverNameOf: _driverName,
                primaryLabel: 'السماح بإعادة التسجيل',
                primaryIcon: Icons.lock_open_rounded,
                onPrimary: _approveEdit,
                secondaryLabel: 'رفض الطلب',
                secondaryIcon: Icons.block_rounded,
                onSecondary: _denyEdit,
                secondaryIsDestructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoutesList extends StatelessWidget {
  final Stream<List<PlannedRoute>> stream;
  final String emptyTitle;
  final String emptyHint;
  final Future<String> Function(String driverId) driverNameOf;
  final String primaryLabel;
  final IconData primaryIcon;
  final Future<void> Function(PlannedRoute) onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final Future<void> Function(PlannedRoute) onSecondary;
  final bool secondaryIsDestructive;

  const _RoutesList({
    required this.stream,
    required this.emptyTitle,
    required this.emptyHint,
    required this.driverNameOf,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    this.secondaryIsDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlannedRoute>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('خطأ: ${snap.error}'));
        }
        final list = snap.data ?? const <PlannedRoute>[];
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route_rounded,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    emptyTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emptyHint,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i];
            return _RouteCard(
              route: r,
              driverNameOf: driverNameOf,
              primaryLabel: primaryLabel,
              primaryIcon: primaryIcon,
              onPrimary: () => onPrimary(r),
              secondaryLabel: secondaryLabel,
              secondaryIcon: secondaryIcon,
              onSecondary: () => onSecondary(r),
              secondaryIsDestructive: secondaryIsDestructive,
            );
          },
        );
      },
    );
  }
}

class _RouteCard extends StatefulWidget {
  final PlannedRoute route;
  final Future<String> Function(String) driverNameOf;
  final String primaryLabel;
  final IconData primaryIcon;
  final Future<void> Function() onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final Future<void> Function() onSecondary;
  final bool secondaryIsDestructive;

  const _RouteCard({
    required this.route,
    required this.driverNameOf,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onSecondary,
    required this.secondaryIsDestructive,
  });

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  bool _busy = false;
  String? _driverName;

  @override
  void initState() {
    super.initState();
    widget.driverNameOf(widget.route.driverId).then((n) {
      if (mounted) setState(() => _driverName = n);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    final km = ((r.distanceMeters ?? 0) / 1000).toStringAsFixed(1);
    final dirColor = r.direction == RouteDirection.outbound
        ? const Color(0xFF2563EB)
        : const Color(0xFF059669);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: dirColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r.direction.labelAr,
                    style: TextStyle(
                      color: dirColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.lineName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  r.status.labelAr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: r.isApproved
                        ? const Color(0xFF16A34A)
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'السائق: ${_driverName ?? '…'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 2),
            Text(
              '${r.points.length} نقطة · $km كم',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (r.editRequestPending)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'طلب تعديل بانتظار القرار',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _run(widget.onPrimary),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(widget.primaryIcon, size: 18),
                    label: Text(
                      widget.primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(widget.onSecondary),
                    icon: Icon(widget.secondaryIcon, size: 18),
                    label: Text(
                      widget.secondaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.secondaryIsDestructive
                          ? Colors.red.shade700
                          : AppTheme.textColor,
                      side: BorderSide(
                        color: widget.secondaryIsDestructive
                            ? Colors.red.shade200
                            : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
