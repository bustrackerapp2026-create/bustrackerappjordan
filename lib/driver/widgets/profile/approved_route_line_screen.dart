import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// نقطة الدخول المستقلة لميزة "خط المسار المعتمد".
///
/// تبقى الواجهة في ملف منفصل حتى يمكن تطويرها لاحقًا إلى أقسام/مكوّنات
/// مستقلة دون تضخيم ProfileBody.
class ApprovedRouteLineScreen extends StatelessWidget {
  const ApprovedRouteLineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'خط المسار المعتمد',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  size: 38,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'خط المسار المعتمد',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'هذه مساحة مستقلة لإدارة المسار المعتمد للسائق، وسيتم تطويرها لاحقًا دون خلطها مع طلبات الركاب أو تعديل الملف الشخصي.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
