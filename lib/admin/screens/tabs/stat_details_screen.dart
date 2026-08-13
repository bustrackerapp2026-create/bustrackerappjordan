import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/bus_capacity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/analytics_service.dart';
import '../../../services/firestore_service.dart';

class StatDetailsScreen extends StatefulWidget {
  final String title;
  final String queryType;

  const StatDetailsScreen({
    super.key,
    required this.title,
    required this.queryType,
  });

  @override
  State<StatDetailsScreen> createState() => _StatDetailsScreenState();
}

class _StatDetailsScreenState extends State<StatDetailsScreen> {
  final FirestoreService _firestore = FirestoreService();
  final Set<String> _busyIds = {};

  bool get _isVerificationList =>
      widget.queryType == 'pending' ||
      widget.queryType == 'verified' ||
      widget.queryType == 'rejected' ||
      widget.queryType == 'driver';

  Stream<List<UserModel>> _watchUsers() {
    return FirebaseFirestore.instance.collection('users').snapshots().map((snap) {
      final list = <UserModel>[];
      for (final doc in snap.docs) {
        final user = UserModel.fromMap(doc.data(), doc.id);
        if (_matchesFilter(user)) list.add(user);
      }
      list.sort((a, b) => a.fullName.compareTo(b.fullName));
      return list;
    });
  }

  bool _matchesFilter(UserModel user) {
    final type = user.userType.toLowerCase();
    final needsApproval =
        type == 'driver' || type == 'service' || type == 'bus_company';

    switch (widget.queryType) {
      case 'passenger':
        return type == 'passenger';
      case 'driver':
        return type == 'driver';
      case 'service':
        return type == 'service';
      case 'bus_company':
        return type == 'bus_company';
      case 'pending':
        return needsApproval && !user.isVerified && !user.isRejected;
      case 'verified':
        return needsApproval && user.isVerified && !user.isRejected;
      case 'rejected':
        return needsApproval && user.isRejected;
      case 'active_buses':
        return type == 'driver';
      case 'active_passengers':
        return type == 'passenger';
      case 'active_services':
        return type == 'service';
      default:
        return true;
    }
  }

  Future<void> _approve(UserModel user) async {
    if (_busyIds.contains(user.uid)) return;
    setState(() => _busyIds.add(user.uid));
    try {
      await _firestore.approveDriver(user.uid);
      AnalyticsService().adminDriverApproved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تمت الموافقة على ${user.fullName}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل الموافقة: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(user.uid));
    }
  }

  Future<void> _reject(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Text('هل تريد رفض طلب ${user.fullName}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (_busyIds.contains(user.uid)) return;
    setState(() => _busyIds.add(user.uid));
    try {
      await _firestore.rejectDriver(user.uid);
      AnalyticsService().adminDriverRejected();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفض طلب ${user.fullName}'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل الرفض: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(user.uid));
    }
  }

  Future<void> _resetToPending(UserModel user) async {
    if (_busyIds.contains(user.uid)) return;
    setState(() => _busyIds.add(user.uid));
    try {
      await _firestore.resetDriverVerification(user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إعادة الطلب إلى قائمة الانتظار'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل الإعادة: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('قائمة: ${widget.title}'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: StreamBuilder<List<UserModel>>(
          stream: _watchUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('❌ حدث خطأ: ${snapshot.error}'));
            }

            final users = snapshot.data ?? const <UserModel>[];

            if (users.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'لا توجد بيانات مطابقة حالياً',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final busy = _busyIds.contains(user.uid);
                return _UserCard(
                  user: user,
                  busy: busy,
                  showActions: _isVerificationList,
                  onApprove: () => _approve(user),
                  onReject: () => _reject(user),
                  onReset: () => _resetToPending(user),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool busy;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReset;

  const _UserCard({
    required this.user,
    required this.busy,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
    required this.onReset,
  });

  Color get _statusColor {
    if (user.isRejected) return Colors.red;
    if (user.isVerified) return Colors.green;
    return Colors.orange;
  }

  String get _statusLabel {
    if (user.isRejected) return 'مرفوض';
    if (user.isVerified) return 'موثّق';
    return 'بانتظار الموافقة';
  }

  @override
  Widget build(BuildContext context) {
    final type = user.userType.toLowerCase();
    final isDriverLike =
        type == 'driver' || type == 'service' || type == 'bus_company';

    return Card(
      key: ValueKey(user.uid),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage:
                      user.hasPhoto ? NetworkImage(user.photoUrl!) : null,
                  child: user.hasPhoto
                      ? null
                      : const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isNotEmpty ? user.fullName : 'بدون اسم',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDriverLike)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(Icons.badge_outlined, user.displayUserType),
                if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                  _chip(Icons.phone_outlined, user.phoneNumber!),
                if (user.busNumber != null && user.busNumber!.isNotEmpty)
                  _chip(Icons.directions_bus_outlined, 'باص ${user.busNumber}'),
                if (user.route != null && user.route!.isNotEmpty)
                  _chip(Icons.route_outlined, user.route!),
                if (user.capacity != null)
                  _chip(
                    Icons.event_seat_outlined,
                    BusCapacity.label(user.capacity),
                  ),
              ],
            ),
            if (showActions && isDriverLike) ...[
              const SizedBox(height: 12),
              if (busy)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                Row(
                  children: [
                    if (!user.isVerified) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('موافقة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!user.isRejected)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('رفض'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    if (user.isRejected || user.isVerified) ...[
                      if (!user.isVerified) const SizedBox(width: 8),
                      if (user.isRejected)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: onReset,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: const Text('إعادة للانتظار'),
                          ),
                        ),
                      if (user.isVerified && !user.isRejected)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: onReset,
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('إلغاء التوثيق'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
