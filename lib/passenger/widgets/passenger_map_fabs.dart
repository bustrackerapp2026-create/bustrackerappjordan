import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// أزرار خريطة الراكب.
class PassengerMapFabs extends StatelessWidget {
  final bool findingNearest;
  final bool findingNearby;
  final bool nearbyModeActive;
  final bool hasDestination;
  final bool isLoadingPassengerLocation;
  final bool isAddingPickupPoint;
  final VoidCallback? onNearestBus;
  final VoidCallback? onNearbyBuses;
  final VoidCallback? onSetDestination;
  final VoidCallback onMapLayers;
  final VoidCallback onMyLocation;
  final VoidCallback onTogglePickup;

  const PassengerMapFabs({
    super.key,
    required this.findingNearest,
    this.findingNearby = false,
    this.nearbyModeActive = false,
    this.hasDestination = false,
    required this.isLoadingPassengerLocation,
    required this.isAddingPickupPoint,
    required this.onNearestBus,
    this.onNearbyBuses,
    this.onSetDestination,
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
          heroTag: 'passenger_nearby_buses',
          onPressed: findingNearby ? null : onNearbyBuses,
          backgroundColor: nearbyModeActive
              ? const Color(0xFF0F766E)
              : const Color(0xFF0D9488),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: findingNearby
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  nearbyModeActive
                      ? Icons.alt_route_rounded
                      : Icons.hail_rounded,
                  size: 20,
                ),
          label: Text(
            nearbyModeActive ? 'خطوط موقعي' : 'باصات من هنا',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'passenger_destination',
          onPressed: onSetDestination,
          backgroundColor:
              hasDestination ? const Color(0xFF7C3AED) : Colors.white,
          foregroundColor:
              hasDestination ? Colors.white : const Color(0xFF6D28D9),
          elevation: 4,
          icon: Icon(
            hasDestination ? Icons.flag_rounded : Icons.flag_outlined,
            size: 20,
          ),
          label: Text(
            hasDestination ? 'تغيير الوجهة' : 'إلى أين؟',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.small(
          heroTag: 'passenger_nearest_bus',
          onPressed: onNearestBus,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F766E),
          elevation: 3,
          child: findingNearest
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.near_me_rounded, size: 20),
        ),
        const SizedBox(height: 10),
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
