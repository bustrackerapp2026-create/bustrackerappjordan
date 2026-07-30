import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userData = authProvider.userData;

        String title;
        String message;
        IconData icon;
        Color iconColor;

        if (userData?.isRejected == true) {
          title = '❌ تم رفض طلبك';
          message =
              'عذراً، لم تتم الموافقة على طلبك. يرجى التواصل مع الدعم لمعرفة السبب.';
          icon = Icons.cancel_outlined;
          iconColor = Colors.red;
        } else {
          title = '⏳ حسابك قيد المراجعة';
          message =
              'تم إنشاء حساب السائق بنجاح، وسيتم تفعيله من قبل الإدارة بعد التأكد من البيانات.';
          icon = Icons.hourglass_top_rounded;
          iconColor = Colors.orange;
        }

        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 80, color: iconColor),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.read<AuthProvider>().signOut(),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
