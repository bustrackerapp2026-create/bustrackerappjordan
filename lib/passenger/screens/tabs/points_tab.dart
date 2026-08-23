import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// شاشة «نقاطي» للراكب — محتوى مستقل يُكمَّل لاحقاً حسب طلبك.
class PointsTab extends StatelessWidget {
  const PointsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.18),
                        const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    size: 44,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'نقاطي',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'هنا ستظهر نقاطك ومكافآتك قريباً.\nالمحتوى يُضاف لاحقاً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
