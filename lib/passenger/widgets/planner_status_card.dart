import 'package:flutter/material.dart';

import '../../presentation/planner_ui_projection.dart';


/// Presentation-only status consumer for the latest Planner request.
///
/// It has no knowledge of routes, Journey Options, vehicles, Mapbox,
/// NearbyRoutesService, or route lifecycle.
class PlannerStatusCard extends StatelessWidget {
  final PlannerUiProjection projection;
  final VoidCallback? onRetry;

  const PlannerStatusCard({
    super.key,
    required this.projection,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (projection.status) {
      case PlannerUiProjectionStatus.idle:
      case PlannerUiProjectionStatus.success:
        return const SizedBox.shrink();
      case PlannerUiProjectionStatus.loading:
        return _statusCard(
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          title: 'جاري التخطيط...',
          message: 'نبحث عن رحلة مناسبة لوجهتك.',
        );
      case PlannerUiProjectionStatus.empty:
        return _statusCard(
          icon: const Icon(Icons.route_rounded, size: 24),
          title: 'لا توجد رحلة متاحة حاليًا',
          message: 'لم ينتج طلب التخطيط الحالي رحلة مؤهلة نحو وجهتك.',
        );
      case PlannerUiProjectionStatus.error:
        return _statusCard(
          icon: const Icon(Icons.error_outline_rounded, size: 24),
          title: 'تعذر تخطيط الرحلة',
          message: 'حدث خطأ أثناء البحث عن رحلة. حاول مرة أخرى.',
          action: onRetry == null
              ? null
              : TextButton(
                  onPressed: onRetry,
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
        );
    }
  }

  Widget _statusCard({
    required Widget icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Center(child: icon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 6),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
