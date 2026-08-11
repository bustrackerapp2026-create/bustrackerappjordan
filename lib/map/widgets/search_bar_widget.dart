import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final String selectedRoute;
  final List<String> routes;
  final ValueChanged<String> onRouteChanged;
  final ValueChanged<String> onSearchSubmitted;

  const SearchBarWidget({
    super.key,
    required this.selectedRoute,
    required this.routes,
    required this.onRouteChanged,
    required this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ فحص أمان لمنع انهيار التطبيق إذا كانت القيمة المختارة غير موجودة
    final effectiveValue = routes.contains(selectedRoute)
        ? selectedRoute
        : (routes.isNotEmpty ? routes.first : null);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final hintColor = textColor.withValues(alpha: 0.5);
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Card(
      elevation: 6,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 8.0),
              child: Icon(
                Icons.search,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث عن وجهة أو خط...',
                  hintStyle: TextStyle(color: hintColor, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
                onSubmitted: onSearchSubmitted,
              ),
            ),
            Container(
              width: 1,
              height: 30,
              color: dividerColor,
            ),
            DropdownButton<String>(
              value: effectiveValue,
              underline: const SizedBox(),
              dropdownColor: surface,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppTheme.primaryColor,
              ),
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              items: routes.map((route) {
                return DropdownMenuItem(
                  value: route,
                  child: Text(route),
                );
              }).toList(),
              onChanged: (newRoute) {
                if (newRoute != null) {
                  onRouteChanged(newRoute);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
