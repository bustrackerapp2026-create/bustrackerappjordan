import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';

class VerifyDriversTab extends StatelessWidget {
  const VerifyDriversTab({super.key});

  Future<void> _verifyDriver(BuildContext context, String uid, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirestoreService().updateUserData(uid, {'isVerified': true});
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ تم توثيق السائق $name بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ فشل توثيق السائق: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('userType', isEqualTo: 'driver')
            .where('isVerified', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('❌ حدث خطأ أثناء تحميل البيانات: ${snapshot.error}'),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            child: Icon(Icons.directions_bus, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          Text('رقم الحافلة: ${driver.busNumber.isNotEmpty ? driver.busNumber : "غير محدد"}'),
                          Text('الخط: ${driver.route.isNotEmpty ? driver.route : "غير محدد"}'),
                        ],
                      ),
                      if (driver.phoneNumber.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('الهاتف: ${driver.phoneNumber}'),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _verifyDriver(
                            context,
                            driver.uid,
                            driver.fullName,
                          ),
                          icon: const Icon(Icons.verified),
                          label: const Text('موافقة وتوثيق الحساب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
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
      ),
    );
  }
}
