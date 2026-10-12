import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/driver_route_request.dart';
import '../../../models/planned_route.dart';
import '../../../services/driver_route_request_service.dart';
import '../../../services/route_plan_service.dart';

/// مراجعة طلبات المسارات التي لم تكن موجودة في الكتالوج عند التسجيل.
/// اعتماد هذا الطلب ينشئ DriverLineAssignment، ولا يعتمد حساب السائق نفسه.
class RouteRequestsTab extends StatefulWidget {
  const RouteRequestsTab({super.key});

  @override
  State<RouteRequestsTab> createState() => _RouteRequestsTabState();
}

class _RouteRequestsTabState extends State<RouteRequestsTab> {
  final DriverRouteRequestService _service = DriverRouteRequestService();
  final RoutePlanService _routes = RoutePlanService();
  final Set<String> _busyIds = <String>{};

  Future<String> _userName(String driverId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();
      final name = snap.data()?['fullName']?.toString().trim();
      return name == null || name.isEmpty ? 'غير معروف' : name;
    } catch (_) {
      return 'غير معروف';
    }
  }

  Future<List<PlannedRoute>> _matchingApprovedRoutes(
    DriverRouteRequest request,
  ) async {
    final list = await _routes.listApprovedRoutes(limit: 200);
    return list
        .where(
          (route) =>
              route.lineName.trim() == request.lineName.trim() &&
              route.direction == request.direction &&
              route.isApproved &&
              route.points.length >= 2,
        )
        .toList();
  }

  Future<PlannedRoute?> _chooseRoute(DriverRouteRequest request) async {
    final matches = await _matchingApprovedRoutes(request);
    if (!mounted) return null;

    return showDialog<PlannedRoute>(
      context: context,
      builder: (dialogContext) {
        if (matches.isEmpty) {
          return AlertDialog(
            title: const Text('لا يوجد مسار جاهز'),
            content: Text(
              'لا يوجد حاليًا مسار معتمد مكتمل يطابق «${request.lineName}» واتجاه ${request.direction.labelAr}.\n\nأنشئ أو سجّل المسار أولًا ثم عد إلى طلب السائق.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('اختيار المسار المعتمد'),
          content: SizedBox(
            width: 520,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: matches.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final route = matches[index];
                final km = ((route.distanceMeters ?? 0) / 1000)
                    .toStringAsFixed(1);
                return ListTile(
                  leading: const Icon(
                    Icons.route_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(route.lineName),
                  subtitle: Text(
                    '${route.direction.labelAr} • ${route.points.length} نقطة • $km كم',
                  ),
                  onTap: () => Navigator.pop(dialogContext, route),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approve(DriverRouteRequest request) async {
    if (_busyIds.contains(request.id)) return;
    final adminId = FirebaseAuth.instance.currentUser?.uid.trim();
    if (adminId == null || adminId.isEmpty) {
      _snack('تعذر تحديد حساب الأدمن الحالي.', error: true);
      return;
    }

    final route = await _chooseRoute(request);
    if (route == null) return;

    setState(() => _busyIds.add(request.id));
    try {
      await _service.approveRequest(
        requestId: request.id,
        adminId: adminId,
        routeId: route.id,
      );
      _snack('تم اعتماد طلب المسار وإنشاء تعيينه للسائق.');
    } catch (e) {
      _snack('فشل اعتماد طلب المسار: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  Future<void> _reject(DriverRouteRequest request) async {
    if (_busyIds.contains(request.id)) return;

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض طلب المسار'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'سبب الرفض (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, reasonController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    final adminId = FirebaseAuth.instance.currentUser?.uid.trim();
    if (adminId == null || adminId.isEmpty) {
      _snack('تعذر تحديد حساب الأدمن الحالي.', error: true);
      return;
    }

    setState(() => _busyIds.add(request.id));
    try {
      await _service.rejectRequest(
        requestId: request.id,
        adminId: adminId,
        reason: reason,
      );
      _snack('تم رفض طلب المسار.');
    } catch (e) {
      _snack('فشل رفض طلب المسار: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverRouteRequest>>(
      stream: _service.watchPendingForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ في طلبات المسارات: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? const <DriverRouteRequest>[];
        if (requests.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alt_route_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'لا توجد طلبات مسارات جديدة معلقة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _RouteRequestCard(
              request: request,
              userName: _userName(request.driverId),
              busy: _busyIds.contains(request.id),
              onApprove: () => _approve(request),
              onReject: () => _reject(request),
            );
          },
        );
      },
    );
  }
}

class _RouteRequestCard extends StatefulWidget {
  final DriverRouteRequest request;
  final Future<String> userName;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RouteRequestCard({
    required this.request,
    required this.userName,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_RouteRequestCard> createState() => _RouteRequestCardState();
}

class _RouteRequestCardState extends State<_RouteRequestCard> {
  String? _name;

  @override
  void initState() {
    super.initState();
    widget.userName.then((value) {
      if (mounted) setState(() => _name = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final dirColor = r.direction == RouteDirection.outbound
        ? Colors.blue.shade700
        : Colors.green.shade700;

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
                Expanded(
                  child: Text(
                    r.lineName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: dirColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r.direction.labelAr,
                    style: TextStyle(
                      color: dirColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('السائق: ${_name ?? '…'}'),
            const SizedBox(height: 6),
            _InfoLine(label: 'البداية', value: r.startName),
            if ((r.middleName ?? '').trim().isNotEmpty)
              _InfoLine(label: 'نقطة وسطية', value: r.middleName!.trim()),
            _InfoLine(label: 'النهاية', value: r.endName),
            const SizedBox(height: 12),
            if (widget.busy)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onApprove,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('اعتماد واختيار المسار'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onReject,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
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

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
