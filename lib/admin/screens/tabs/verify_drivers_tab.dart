import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';

class VerifyDriversTab extends StatefulWidget {
  const VerifyDriversTab({super.key});

  @override
  State<VerifyDriversTab> createState() => _VerifyDriversTabState();
}

class _VerifyDriversTabState extends State<VerifyDriversTab> {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _verifyDriver(
      BuildContext context, String uid, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreService.updateUserData(uid, {'isVerified': true});
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ تم توثيق السائق $name بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ فشل توثيق السائق: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ دالة رفض السائق
  Future<void> _rejectDriver(
      BuildContext context, String uid, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreService.rejectDriver(uid);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('🗑️ تم رفض طلب السائق $name.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ فشل رفض السائق: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ عرض حوار تأكيد الرفض
  void _showRejectDialog(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض طلب التوثيق'),
        content: Text('هل أنت متأكد من رفض طلب السائق "$name"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _rejectDriver(context, uid, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 طلبات التوثيق المعلقة'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textColor,
        elevation: 1,
      ),
      body: Column(
        children: [
          // ✅ بطاقة الإحصائيات (في الأعلى)
          FutureBuilder<Map<String, int>>(
            future: _firestoreService.getDriversStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                      child: Text('⚠️ خطأ في الإحصائيات: ${snapshot.error}')),
                );
              }
              final stats = snapshot.data ?? {};
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildStatCard(
                        'المعلقون', stats['pending'] ?? 0, Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatCard(
                        'الموثقون', stats['verified'] ?? 0, Colors.green),
                    const SizedBox(width: 8),
                    _buildStatCard(
                        'المرفوضون', stats['rejected'] ?? 0, Colors.red),
                    const SizedBox(width: 8),
                    _buildStatCard(
                        'الإجمالي', stats['total'] ?? 0, Colors.blue),
                  ],
                ),
              );
            },
          ),
          // ✅ قائمة السائقين غير الموثقين (استبعاد المرفوضين)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('userType', isEqualTo: 'driver')
                  .where('isVerified', isEqualTo: false)
                  .where('isRejected', isEqualTo: false) // ✅ استبعاد المرفوضين
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                        '❌ حدث خطأ أثناء تحميل البيانات: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 80, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات توثيق معلقة حالياً',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'جميع السائقين المسجلين تم توثيقهم بنجاح.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final driver = UserModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );

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
                                  child: Icon(Icons.directions_bus,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driver.fullName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        driver.email,
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
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'رقم الحافلة: ${driver.busNumber.isNotEmpty ? driver.busNumber : "غير محدد"}'),
                                Text(
                                    'الخط: ${driver.route.isNotEmpty ? driver.route : "غير محدد"}'),
                              ],
                            ),
                            if (driver.phoneNumber.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('الهاتف: ${driver.phoneNumber}'),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // زر الموافقة
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _verifyDriver(
                                      context,
                                      driver.uid,
                                      driver.fullName,
                                    ),
                                    icon: const Icon(Icons.verified),
                                    label: const Text('موافقة'),
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
                                // ✅ زر الرفض (جديد)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showRejectDialog(
                                      context,
                                      driver.uid,
                                      driver.fullName,
                                    ),
                                    icon: const Icon(Icons.close),
                                    label: const Text('رفض'),
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
          ),
        ],
      ),
    );
  }

  // ✅ دالة مساعدة لبناء بطاقة الإحصائيات
  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
