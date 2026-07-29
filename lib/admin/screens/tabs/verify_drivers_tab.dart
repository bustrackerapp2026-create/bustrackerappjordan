import 'package:flutter/material.dart';

class VerifyDriversTab extends StatelessWidget {
  const VerifyDriversTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pending_actions, size: 80, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              '📋 طلبات التحقق من السائقين',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('سيتم عرض قائمة السائقين غير الموثقين هنا قريباً.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('جاري جلب بيانات السائقين...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('تحديث القائمة'),
            ),
          ],
        ),
      ),
    );
  }
}
