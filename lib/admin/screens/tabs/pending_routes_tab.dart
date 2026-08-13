import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/planned_route.dart';
import '../../../services/route_plan_service.dart';

/// تبويب الأدمن: طلبات تعديل مسارات الخطوط المشتركة.
class PendingRoutesTab extends StatefulWidget {
  const PendingRoutesTab({super.key});

  @override
  State<PendingRoutesTab> createState() => _PendingRoutesTabState();
}

class _PendingRoutesTabState extends State<PendingRoutesTab> {
  final RoutePlanService _service = RoutePlanService();

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

  Future<String> _userName(String userId) async {
    if (userId.isEmpty) return '—';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = doc.data()?['fullName']?.toString().trim();
      return (name != null && name.isNotEmpty) ? name : '—';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _approveEdit(PlannedRoute r) async {
    try {
      await _service.approveEditRequest(r.id);
      _snack('تمت الموافقة — يمكن للسائق إعادة تسجيل المسار');
    } catch (e) {
      _snack('فشل: $e', error: true);
    }
  }

  Future<void> _denyEdit(PlannedRoute r) async {
    try {
      await _service.denyEditRequest(r.id);
      _snack('تم رفض طلب التعديل');
    } catch (e) {
      _snack('فشل: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlannedRoute>>(
      stream: _service.watchEditRequests(),
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
                  const Text(
                    'لا توجد طلبات تعديل مسارات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'المسارات الجديدة تُخزَّن تلقائياً. تظهر هنا فقط طلبات تعديل المسارات المخزّنة.',
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
            return _EditRequestCard(
              route: r,
              userNameOf: _userName,
              onApprove: () => _approveEdit(r),
              onDeny: () => _denyEdit(r),
            );
          },
        );
      },
    );
  }
}

class _EditRequestCard extends StatefulWidget {
  final PlannedRoute route;
  final Future<String> Function(String) userNameOf;
  final Future<void> Function() onApprove;
  final Future<void> Function() onDeny;

  const _EditRequestCard({
    required this.route,
    required this.userNameOf,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  State<_EditRequestCard> createState() => _EditRequestCardState();
}

class _EditRequestCardState extends State<_EditRequestCard> {
  bool _busy = false;
  String? _requesterName;

  @override
  void initState() {
    super.initState();
    final id = widget.route.editRequestedBy ?? widget.route.createdBy;
    widget.userNameOf(id).then((n) {
      if (mounted) setState(() => _requesterName = n);
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
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'مقدّم الطلب: ${_requesterName ?? '…'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            Text(
              '${r.points.length} نقطة · $km كم',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if ((r.editRequestReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Text(
                  'السبب: ${r.editRequestReason}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _run(widget.onApprove),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text(
                      'السماح بإعادة التسجيل',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
                    onPressed: _busy ? null : () => _run(widget.onDeny),
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: const Text(
                      'رفض',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
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
