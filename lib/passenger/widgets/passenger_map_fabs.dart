import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// أزرار خريطة الراكب (أقرب باص، طبقات، موقعي، إضافة نقطة).
class PassengerMapFabs extends StatelessWidget {
  final bool findingNearest;
  final bool isLoadingPassengerLocation;
  final bool isAddingPickupPoint;
  final VoidCallback? onNearestBus;
  final VoidCallback onMapLayers;
  final VoidCallback onMyLocation;
  final VoidCallback onTogglePickup;

  const PassengerMapFabs({
    super.key,
    required this.findingNearest,
    required this.isLoadingPassengerLocation,
    required this.isAddingPickupPoint,
    required this.onNearestBus,
    required this.onMapLayers,
    required this.onMyLocation,
    required this.onTogglePickup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'passenger_nearest_bus',
          onPressed: onNearestBus,
          backgroundColor: const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: findingNearest
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.near_me_rounded, size: 20),
          label: const Text(
            'أقرب باص',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'passenger_map_layers',
          onPressed: onMapLayers,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textColor,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.layers, size: 26),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'passenger_my_location',
          onPressed: onMyLocation,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          elevation: 4,
          shape: const CircleBorder(),
          child: isLoadingPassengerLocation
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(Icons.my_location, size: 28),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'passenger_add_pickup',
          onPressed: onTogglePickup,
          backgroundColor: isAddingPickupPoint ? Colors.red : Colors.white,
          foregroundColor:
              isAddingPickupPoint ? Colors.white : AppTheme.primaryColor,
          elevation: 4,
          shape: const CircleBorder(),
          child: Icon(
            isAddingPickupPoint
                ? Icons.close
                : Icons.add_location_alt_rounded,
          ),
        ),
      ],
    );
  }
}
