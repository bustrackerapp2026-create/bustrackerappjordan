import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// أزرار خريطة الأدمن العائمة.
class AdminMapFabs extends StatelessWidget {
  final bool showPassengers;
  final bool isAddingPickupPoint;
  final bool isDrawingRoute;
  final bool isLoadingLocation;
  final VoidCallback onTogglePassengers;
  final VoidCallback onTogglePickup;
  final VoidCallback onToggleDrawRoute;
  final VoidCallback onMyLocation;
  final VoidCallback onMapLayers;

  const AdminMapFabs({
    super.key,
    required this.showPassengers,
    required this.isAddingPickupPoint,
    required this.isDrawingRoute,
    required this.isLoadingLocation,
    required this.onTogglePassengers,
    required this.onTogglePickup,
    required this.onToggleDrawRoute,
    required this.onMyLocation,
    required this.onMapLayers,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 30,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'admin_passengers_toggle',
            onPressed: onTogglePassengers,
            backgroundColor:
                showPassengers ? Colors.blue.shade700 : Colors.grey,
            foregroundColor: Colors.white,
            child: Icon(showPassengers ? Icons.person : Icons.person_off),
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
