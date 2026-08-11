import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/pickup_point_model.dart';
import '../../../services/pickup_point_service.dart';
import '../../../services/pickup_point_service_exception.dart';
import '../../../l10n/app_localizations.dart';

class PendingPointsTab extends StatefulWidget {
  final void Function({
    required double latitude,
    required double longitude,
    required String pointName,
    String? pointId,
  })? onShowOnMap;

  const PendingPointsTab({super.key, this.onShowOnMap});

  @override
  State<PendingPointsTab> createState() => _PendingPointsTabState();
}

class _PendingPointsTabState extends State<PendingPointsTab> {
  final PickupPointService _service = PickupPointService();
  final Set<String> _processingIds = {};

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _userTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'driver':
        return l10n.driver;
      case 'passenger':
        return l10n.passenger;
      case 'admin':
        return l10n.admin;
      case 'service':
        return l10n.isArabic ? 'سرفيس' : 'Service';
      case 'bus_company':
        return l10n.isArabic ? 'شركة باصات' : 'Bus company';
      default:
        return type;
    }
  }

  Future<Map<String, String>> _loadAdderInfo(String userId) async {
    if (userId.isEmpty) {
      return {'name': '—', 'email': '', 'phone': ''};
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists || doc.data() == null) {
        return {'name': '—', 'email': '', 'phone': ''};
      }
      final data = doc.data()!;
      return {
        'name': (data['fullName'] as String?)?.trim().isNotEmpty == true
            ? data['fullName'] as String
            : '—',
        'email': (data['email'] as String?) ?? '',
        'phone': (data['phoneNumber'] as String?) ?? '',
      };
    } catch (_) {
      return {'name': '—', 'email': '', 'phone': ''};
    }
  }

  Future<void> _showPointDetails(PickupPointModel point) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return FutureBuilder<Map<String, String>>(
          future: _loadAdderInfo(point.addedBy),
          builder: (context, snapshot) {
            final adder = snapshot.data;
            final loading = snapshot.connectionState == ConnectionState.waiting;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      point.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.underReview,
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor
                              .withValues(alpha: 0.15),
                          child: Icon(
                            point.addedByUserType == 'driver'
                                ? Icons.directions_bus
                                : Icons.person,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(adder?['name'] ?? '—'),
                        subtitle: Text(
                          [
                            _userTypeLabel(point.addedByUserType, l10n),
                            if ((adder?['phone'] ?? '').isNotEmpty)
                              adder!['phone'],
                            if ((adder?['email'] ?? '').isNotEmpty)
                              adder!['email'],
                          ].join(' · '),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          widget.onShowOnMap?.call(
                            latitude: point.latitude,
                            longitude: point.longitude,
                            pointName: point.name,
                            pointId: point.id,
                          );
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: Text(l10n.showOnMap),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approvePoint(String id, String name) async {
    if (_processingIds.contains(id)) return;
    setState(() => _processingIds.add(id));
    final l10n = AppLocalizations.of(context);

    try {
      await _service.approvePickupPoint(id);
      _showMessage(l10n.pointApproved(name));
    } catch (e) {
      _showMessage(_getUserFriendlyErrorMessage(e, l10n), isError: true);
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  Future<void> _rejectPoint(String id, String name) async {
    if (_processingIds.contains(id)) return;
    setState(() => _processingIds.add(id));
    final l10n = AppLocalizations.of(context);

    try {
      await _service.rejectPickupPoint(id);
      _showMessage(l10n.pointRejected(name));
    } catch (e) {
      _showMessage(_getUserFriendlyErrorMessage(e, l10n), isError: true);
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  Future<void> _editPoint(PickupPointModel point) async {
    if (_processingIds.contains(point.id)) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _EditPointNameDialog(
        initialName: point.name,
        l10n: l10n,
      ),
    );

    if (!mounted) return;
    if (result == null || result.isEmpty) return;

    setState(() => _processingIds.add(point.id));

    try {
      await _service.updatePickupPoint(
        pointId: point.id,
        data: {
          'name': result,
          'status': 'pending',
          'suggestedEdit': 'admin edit',
        },
      );

      if (!mounted) return;
      _showMessage(l10n.pointApproved(result));
    } catch (e) {
      if (!mounted) return;
      _showMessage(_getUserFriendlyErrorMessage(e, l10n), isError: true);
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(point.id));
      }
    }
  }

  String _getUserFriendlyErrorMessage(Object error, AppLocalizations l10n) {
    if (error is PickupPointServiceException) {
      return '⚠️ ${error.message}';
    }
    return l10n.isArabic
        ? '❌ فشلت العملية، يرجى المحاولة لاحقاً.'
        : '❌ Operation failed. Please try again later.';
  }

  void _showRejectDialog(String id, String name) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rejectPoint),
        content: Text(l10n.rejectPointConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _rejectPoint(id, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pendingPointsTitle),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
      ),
      body: StreamBuilder<List<PickupPointModel>>(
        stream: _service.getPendingPointsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.errorPrefix}: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          final points = snapshot.data ?? [];

          if (points.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noPendingPoints,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noPendingPointsHint,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: points.length,
            itemBuilder: (context, index) {
              final point = points[index];
              final isProcessing = _processingIds.contains(point.id);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showPointDetails(point),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.location_on,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                point.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_left,
                                color: Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_userTypeLabel(point.addedByUserType, l10n)} · ${point.confirmationCount}',
                          style:
                              const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () =>
                                        _approvePoint(point.id, point.name),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(
                                  isProcessing
                                      ? l10n.processing
                                      : l10n.approve,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () => _showRejectDialog(
                                        point.id, point.name),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.close),
                                label: Text(
                                  isProcessing
                                      ? l10n.processing
                                      : l10n.reject,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () => _editPoint(point),
                            icon: const Icon(Icons.edit_note_outlined),
                            label: Text(l10n.editProfile),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EditPointNameDialog extends StatefulWidget {
  final String initialName;
  final AppLocalizations l10n;

  const _EditPointNameDialog({
    required this.initialName,
    required this.l10n,
  });

  @override
  State<_EditPointNameDialog> createState() => _EditPointNameDialogState();
}

class _EditPointNameDialogState extends State<_EditPointNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.editProfile),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: l10n.isArabic ? 'اسم النقطة' : 'Point name',
        ),
        autofocus: true,
        onSubmitted: (value) {
          final text = value.trim();
          if (text.isNotEmpty) {
            Navigator.pop(context, text);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
