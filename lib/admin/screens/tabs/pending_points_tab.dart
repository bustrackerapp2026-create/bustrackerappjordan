import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/pickup_point_model.dart';
import '../../../services/pickup_point_service.dart';
import '../../../services/pickup_point_service_exception.dart';

class PendingPointsTab extends StatefulWidget {
  const PendingPointsTab({super.key});

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

  Future<void> _approvePoint(String id, String name) async {
    if (_processingIds.contains(id)) return;
    setState(() => _processingIds.add(id));

    try {
      await _service.approvePickupPoint(id);
      _showMessage('✅ تم الموافقة على النقطة "$name" بنجاح!');
    } catch (e) {
      debugPrint('❌ خطأ في الموافقة على النقطة: $e');
      _showMessage(_getUserFriendlyErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  Future<void> _rejectPoint(String id, String name) async {
    if (_processingIds.contains(id)) return;
    setState(() => _processingIds.add(id));

    try {
      await _service.rejectPickupPoint(id);
      _showMessage('🗑️ تم رفض النقطة "$name" بنجاح.');
    } catch (e) {
      debugPrint('❌ خطأ في رفض النقطة: $e');
      _showMessage(_getUserFriendlyErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  Future<void> _editPoint(PickupPointModel point) async {
    if (_processingIds.contains(point.id)) return;
    if (!mounted) return;

    // الحوار يملك الـ controller ويتخلص منه بأمان داخل State الخاص به
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _EditPointNameDialog(
        initialName: point.name,
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
          'suggestedEdit': 'تم تعديلها من لوحة الإدارة',
        },
      );

      if (!mounted) return;
      _showMessage('✅ تم تعديل النقطة "$result"');
    } catch (e) {
      debugPrint('❌ فشل تعديل النقطة: $e');
      if (!mounted) return;
      _showMessage(_getUserFriendlyErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(point.id));
      }
    }
  }

  String _getUserFriendlyErrorMessage(Object error) {
    if (error is PickupPointServiceException) {
      return '⚠️ ${error.message}';
    }
    final text = error.toString();
    if (text.contains('permission') || text.contains('PERMISSION_DENIED')) {
      return '⚠️ ليس لديك صلاحية لإجراء هذه العملية.';
    }
    if (text.contains('not found') || text.contains('NOT_FOUND')) {
      return '⚠️ النقطة غير موجودة أو تم حذفها.';
    }
    return '❌ فشلت العملية، يرجى المحاولة لاحقاً.';
  }

  void _showRejectDialog(String id, String name) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض النقطة'),
        content: Text('هل أنت متأكد من رفض النقطة "$name"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
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
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 نقاط التجمع المعلقة'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textColor,
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
                    '❌ حدث خطأ أثناء تحميل البيانات: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final points = snapshot.data ?? [];

          if (points.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد نقاط تجمع معلقة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'جميع النقاط المضافة تمت الموافقة عليها أو رفضها.',
                    style: TextStyle(color: Colors.grey),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child:
                                Icon(Icons.location_on, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  point.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الموقع: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (point.reviewNote.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'ملاحظات المراجع: ${point.reviewNote}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'أضافها: ${point.addedByUserType == 'driver' ? 'سائق' : 'راكب'}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.thumb_up,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'التأكيدات: ${point.confirmationCount}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isProcessing
                                  ? null
                                  : () => _approvePoint(point.id, point.name),
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
                              label: Text(isProcessing ? 'جاري...' : 'موافقة'),
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
                                  : () =>
                                      _showRejectDialog(point.id, point.name),
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
                              label: Text(isProcessing ? 'جاري...' : 'رفض'),
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
                          onPressed:
                              isProcessing ? null : () => _editPoint(point),
                          icon: const Icon(Icons.edit_note_outlined),
                          label: const Text('تعديل وإرسالها للمراجعة مرة أخرى'),
                        ),
                      ),
                    ],
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

/// حوار تعديل اسم النقطة — يملك TextEditingController ويتخلص منه في dispose فقط
class _EditPointNameDialog extends StatefulWidget {
  final String initialName;

  const _EditPointNameDialog({required this.initialName});

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
    return AlertDialog(
      title: const Text('تعديل النقطة'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'اسم النقطة',
        ),
        textDirection: TextDirection.rtl,
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
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
