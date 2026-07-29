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

    return Card(
      elevation: 6,
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
                decoration: const InputDecoration(
                  hintText: 'ابحث عن وجهة أو خط...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textColor,
                ),
                onSubmitted: onSearchSubmitted,
              ),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.grey.shade300,
            ),
            DropdownButton<String>(
              value: effectiveValue,
              underline: const SizedBox(),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppTheme.primaryColor,
              ),
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textColor,
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
