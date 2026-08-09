import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'map_layer_controller.dart';

/// بطاقة معلومات المكان عند النقر على معلم في الخريطة.
/// تصميم موحّد حديث يعمل على جميع الخرائط (أدمن / سائق / راكب).
class PoiInfoCard {
  PoiInfoCard._();

  static const double _radius = 24;
  static const double _horizontalMargin = 12;
  static const double _bottomMargin = 12;

  static void show(BuildContext context, MapPoiInfo info) {
    final color = colorForCategory(info.category);
    final icon = iconForCategory(info.category);
    final subtitle = _subtitleForCategory(info.category);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;

        return Padding(
          padding: EdgeInsets.only(
            left: _horizontalMargin,
            right: _horizontalMargin,
            bottom: bottomPad + _bottomMargin,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شريط علوي متدرج باللون
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(_radius),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // مقبض السحب
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // أيقونة كبيرة مع ظل خفيف
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    color.withValues(alpha: 0.18),
                                    color.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.25),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.18),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: color, size: 32),
                            ),
                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // شريحة التصنيف
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 14, color: color),
                                        const SizedBox(width: 6),
                                        Text(
                                          info.category,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (info.secondaryName != null &&
                                      info.secondaryName!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      info.secondaryName!,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: Colors.grey.shade600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],

                                  if (subtitle != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.pop(ctx),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // صف معلومات سريعة
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place_rounded,
                                size: 18,
                                color: color.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'معلم على خريطة الأردن',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Mapbox',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // زر إغلاق أنيق
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'إغلاق',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
    if (category.contains('مستشفى') || category.contains('رعاية')) {
      return const Color(0xFFE53935);
    }
    if (category.contains('مطعم') || category.contains('مقهى')) {
      return const Color(0xFFFB8C00);
    }
    if (category.contains('تعليمليم') || category.contains('مدرسة')) {
      return const Color(0xFF1E88E5);
    }
    if (category.contains('مواصلات')) return const Color(0xFF43A047);
    if (category.contains('تسوق')) return const Color(0xFF8E24AA);
    if (category.contains('عبادة')) return const Color(0xFF00897B);
    if (category.contains('حديقة') || category.contains('متنزه')) {
      return const Color(0xFF2E7D32);
    }
    if (category.contains('وقود') || category.contains('مواقف')) {
      return const Color(0xFF6D4C41);
    }
    return AppTheme.primaryColor;
  }

  static IconData iconForCategory(String category) {
    if (category.contains('مستشفى') || category.contains('رعاية')) {
      return Icons.local_hospital_rounded;
    }
    if (category.contains('مطعم') || category.contains('مقهى')) {
      return Icons.restaurant_rounded;
    }
    if (category.contains('تعليمليم') || category.contains('مدرسة')) {
      return Icons.school_rounded;
    }
    if (category.contains('مواصلات')) return Icons.directions_bus_rounded;
    if (category.contains('تسوق')) return Icons.storefront_rounded;
    if (category.contains('عبادة')) return Icons.mosque_rounded;
    if (category.contains('حديقة') || category.contains('متنزه')) {
      return Icons.park_rounded;
    }
    if (category.contains('وقود') || category.contains('مواقف')) {
      return Icons.local_gas_station_rounded;
    }
    return Icons.place_rounded;
  }

  static String? _subtitleForCategory(String category) {
    if (category.contains('مستشفى')) return 'رعاية صحية · مستشفى أو عيادة';
    if (category.contains('مطعم')) return 'مطعم أو مقهى قريب منك';
    if (category.contains('تعليمليم')) return 'مدرسة · جامعة · مركز تعليمي';
    if (category.contains('مواصلات')) return 'محطة أو نقطة مواصلات عامة';
    if (category.contains('تسوق')) return 'متجر أو مركز تسوق';
    if (category.contains('عبادة')) return 'مسجد أو مكان عبادة';
    if (category.contains('حديقة')) return 'حديقة أو متنزه عام';
    if (category.contains('وقود')) return 'محطة وقود أو مواقف سيارات';
    return null;
  }
}
