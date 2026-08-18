import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'admin_route_direction_filter.dart';

/// أزرار خريطة الأدمن العائمة + فلتر اتجاه المسارات.
class AdminMapFabs extends StatelessWidget {
  final bool showPassengers;
  final bool showRoutes;
  final bool isAddingPickupPoint;
  final bool isDrawingRoute;
  final bool isAddingLandmark;
  final bool isAddingTextLabel;
  final bool isLoadingLocation;
  final AdminRouteDirectionFilter routeFilter;
  final int outboundCount;
  final int returnCount;
  final VoidCallback onTogglePassengers;
  final VoidCallback onToggleRoutes;
  final ValueChanged<AdminRouteDirectionFilter> onRouteFilterChanged;
  final VoidCallback onTogglePickup;
  final VoidCallback onToggleDrawRoute;
  final VoidCallback onMyLocation;
  final VoidCallback onMapLayers;
  final VoidCallback onSearchRoutes;
  final VoidCallback onToggleAddLandmark;
  final VoidCallback onToggleAddTextLabel;

  const AdminMapFabs({
    super.key,
    required this.showPassengers,
    required this.showRoutes,
    required this.isAddingPickupPoint,
    required this.isDrawingRoute,
    required this.isAddingLandmark,
    required this.isAddingTextLabel,
    required this.isLoadingLocation,
    required this.routeFilter,
    required this.outboundCount,
    required this.returnCount,
    required this.onTogglePassengers,
    required this.onToggleRoutes,
    required this.onRouteFilterChanged,
    required this.onTogglePickup,
    required this.onToggleDrawRoute,
    required this.onMyLocation,
    required this.onMapLayers,
    required this.onSearchRoutes,
    required this.onToggleAddLandmark,
    required this.onToggleAddTextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showRoutes)
          Positioned(
            bottom: 170,
            left: 12,
            child: AdminRouteDirectionFilterBar(
              value: routeFilter,
              outboundCount: outboundCount,
              returnCount: returnCount,
              onChanged: onRouteFilterChanged,
            ),
          ),
        Positioned(
          bottom: 30,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'admin_passengers_toggle',
            onPressed: onTogglePassengers,
            backgroundColor:
                showPassengers ? Colors.blue.shade700 : Colors.grey,
            foregroundColor: Colors.white,
            tooltip: showPassengers ? 'إخفاء الركاب' : 'إظهار الركاب',
            child: Icon(showPassengers ? Icons.person : Icons.person_off),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'admin_routes_toggle',
            onPressed: onToggleRoutes,
            backgroundColor:
                showRoutes ? routeFilter.accent : Colors.grey.shade600,
            foregroundColor: Colors.white,
            tooltip: showRoutes
                ? 'إخفاء المسارات (${routeFilter.labelAr})'
                : 'إظهار المسارات',
            child: Icon(showRoutes ? routeFilter.icon : Icons.hide_source),
          ),
        ),
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_add_pickup',
            onPressed: onTogglePickup,
            backgroundColor: isAddingPickupPoint ? Colors.red : Colors.orange,
            foregroundColor: Colors.white,
            child: Icon(
              isAddingPickupPoint ? Icons.close : Icons.add_location,
            ),
          ),
        ),
        Positioned(
          bottom: 180,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_draw_route',
            onPressed: onToggleDrawRoute,
            backgroundColor:
                isDrawingRoute ? const Color(0xFF7C3AED) : Colors.white,
            foregroundColor:
                isDrawingRoute ? Colors.white : const Color(0xFF7C3AED),
            child: Icon(
              isDrawingRoute ? Icons.close : Icons.timeline_rounded,
            ),
          ),
        ),
        Positioned(
          bottom: 500,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_add_text_label_fab',
            onPressed: onToggleAddTextLabel,
            backgroundColor:
                isAddingTextLabel ? const Color(0xFF1565C0) : Colors.white,
            foregroundColor:
                isAddingTextLabel ? Colors.white : const Color(0xFF1565C0),
            elevation: 4,
            shape: const CircleBorder(),
            tooltip: isAddingTextLabel ? 'إلغاء إضافة نص' : 'إضافة نص / اسم شارع',
            child: Icon(
              isAddingTextLabel ? Icons.close : Icons.text_fields_rounded,
            ),
          ),
        ),
        Positioned(
          bottom: 420,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_add_landmark_fab',
            onPressed: onToggleAddLandmark,
            backgroundColor:
                isAddingLandmark ? const Color(0xFF00897B) : Colors.white,
            foregroundColor:
                isAddingLandmark ? Colors.white : const Color(0xFF00897B),
            elevation: 4,
            shape: const CircleBorder(),
            tooltip: isAddingLandmark ? 'إلغاء إضافة معلم' : 'إضافة معلم',
            child: Icon(
              isAddingLandmark ? Icons.close : Icons.add_business_rounded,
            ),
          ),
        ),
        Positioned(
          bottom: 340,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_routes_search_fab',
            onPressed: onSearchRoutes,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF7C3AED),
            elevation: 4,
            shape: const CircleBorder(),
            tooltip: 'بحث المسارات',
            child: const Icon(Icons.search_rounded, size: 26),
          ),
        ),
        Positioned(
          bottom: 260,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_location_fab',
            onPressed: onMyLocation,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryColor,
            elevation: 4,
            shape: const CircleBorder(),
            child: isLoadingLocation
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
        Positioned(
          bottom: 30,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_layers_fab',
            onPressed: onMapLayers,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textColor,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.layers_rounded, size: 26),
          ),
        ),
      ],
    );
  }
}
