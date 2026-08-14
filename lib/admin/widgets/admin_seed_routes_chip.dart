import 'package:flutter/material.dart';

/// زر زرع / تحديث مسارات الأردن على خريطة الأدمن.
class AdminSeedRoutesChip extends StatelessWidget {
  final bool isSeeding;
  final int routesCount;
  final VoidCallback? onTap;

  const AdminSeedRoutesChip({
    super.key,
    required this.isSeeding,
    required this.routesCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSeeding)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.route, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                routesCount == 0 ? 'زرع مسارات الأردن' : 'تحديث المسارات',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.blue.shade800,
                ),
              ),
              if (routesCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$routesCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
