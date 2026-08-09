import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'map_layer_controller.dart';

/// بطاقة معلومات المكان عند النقر على معلم في الخريطة.
/// يمكن تعديل الألوان والمسافات هنا بسهولة دون لمس منطق الخريطة.
class PoiInfoCard {
  PoiInfoCard._();

  // ─── إعدادات التصميم (عدّلها كما تريد) ───────────────────────────
  static const double _radius = 20;
  static const double _horizontalMargin = 14;
  static const double _bottomMargin = 14;
  static const double _iconSize = 28;
  static const double _avatarSize = 52;

  static void show(BuildContext context, MapPoiInfo info) {
    final color = colorForCategory(info.category);
    final icon = iconForCategory(info.category);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: _horizontalMargin,
            right: _horizontalMargin,
            bottom: MediaQuery.of(ctx).padding.bottom + _bottomMargin,
          ),
          child: Material(
            color: Colors.white,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(_radius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // مقبض السحب
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // أيقونة التصنيف
                      Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: _iconSize),
                      ),
                      const SizedBox(width: 14),

                      // الاسم + التصنيف
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                info.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                            if (info.secondaryName != null &&
                                info.secondaryName!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                info.secondaryName!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // إغلاق
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── ألوان وأيقونات حسب النوع ───────────────────────────────────

  static Color colorForCategory(String category) {
    if (category.contains('مستشفى')) return const Color(0xFFE53935);
    if (category.contains('مطعم')) return const Color(0xFFFB8C00);
    if (category.contains('تعليمليم')) return const Color(0xFF1E88E5);
    if (category.contains('مواصلات')) return const Color(0xFF43A047);
    if (category.contains('تسوق')) return const Color(0xFF8E24AA);
    if (category.contains('عبادة')) return const Color(0xFF00897B);
    if (category.contains('حديقة')) return const Color(0xFF2E7D32);
    if (category.contains('وقود')) return const Color(0xFF6D4C41);
    return AppTheme.primaryColor;
  }

  static IconData iconForCategory(String category) {
    if (category.contains('مستشفى')) return Icons.local_hospital_rounded;
    if (category.contains('مطعم')) return Icons.restaurant_rounded;
    if (category.contains('تعليمليم')) return Icons.school_rounded;
    if (category.contains('مواصلات')) return Icons.directions_bus_rounded;
    if (category.contains('تسوق')) return Icons.storefront_rounded;
    if (category.contains('عبادة')) return Icons.mosque_rounded;
    if (category.contains('حديقة')) return Icons.park_rounded;
    if (category.contains('وقود')) return Icons.local_gas_station_rounded;
    return Icons.place_rounded;
  }
}
