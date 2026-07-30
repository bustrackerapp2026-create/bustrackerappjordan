import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/pickup_point_model.dart';
import '../../../services/pickup_point_service.dart';

class PendingPointsTab extends StatefulWidget {
  const PendingPointsTab({super.key});

  @override
  State<PendingPointsTab> createState() => _PendingPointsTabState();
}

class _PendingPointsTabState extends State<PendingPointsTab> {
  final PickupPointService _service = PickupPointService();

  // ✅ مجموعة لتخزين المعرفات الجاري معالجتها
  final Set<String> _processingIds = {};

  // ✅ دالة الموافقة (مع منع التكرار)
  Future<void> _approvePoint(String id, String name) async {
    if (_processingIds.contains(id)) return;

    setState(() => _processingIds.add(id));

    try {
      await _service.approvePickupPoint(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم الموافقة على النقطة بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل الموافقة، يرجى المحاولة لاحقاً.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  // ✅ دالة الرفض (مع منع التكرار)
  Future<void> _rejectPoint(String id, String name) async {
    if (_processingIds.contains(id)) return;

    setState(() => _processingIds.add(id));

    try {
      await _service.rejectPickupPoint(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ تم رفض النقطة بنجاح.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل الرفض، يرجى المحاولة لاحقاً.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(id));
      }
    }
  }

  void _showRejectDialog(BuildContext context, String id, String name) {
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
              child: Text('❌ حدث خطأ: ${snapshot.error}'),
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

              // ✅ التحقق مما إذا كانت هذه النقطة قيد المعالجة
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
                            child: Icon(Icons.location_on, color: Colors.white),
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
                          // ✅ زر الموافقة (مع حالة التحميل)
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
                          // ✅ زر الرفض (مع حالة التحميل)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isProcessing
                                  ? null
                                  : () => _showRejectDialog(
                                      context, point.id, point.name),
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
