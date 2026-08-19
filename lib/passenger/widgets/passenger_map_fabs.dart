import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// أزرار خريطة الراكب — الأساسية فقط لتجربة بسيطة.
///
/// الترتيب من الأعلى للأسفل (قرب أسفل الشاشة):
/// 1) باصات من هنا
/// 2) إلى أين؟
/// 3) أقرب باص
/// 4) موقعي
class PassengerMapFabs extends StatelessWidget {
  final bool findingNearest;
  final bool findingNearby;
  final bool nearbyModeActive;
  final bool hasDestination;
  final bool isLoadingPassengerLocation;
  final VoidCallback? onNearestBus;
  final VoidCallback? onNearbyBuses;
  final VoidCallback? onSetDestination;
  final VoidCallback onMyLocation;

  /// اختياري: إعدادات الطبقات (غير ظاهر كزر رئيسي).
  final VoidCallback? onMapLayers;

  const PassengerMapFabs({
    super.key,
    required this.findingNearest,
    this.findingNearby = false,
    this.nearbyModeActive = false,
    this.hasDestination = false,
    required this.isLoadingPassengerLocation,
    required this.onNearestBus,
    this.onNearbyBuses,
    this.onSetDestination,
    required this.onMyLocation,
    this.onMapLayers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1) باصات من هنا — الإجراء الأهم للراكب على الشارع
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

        // 2) إلى أين؟ — تصفية حسب الوجهة
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

        // 3) أقرب باص حي (زر صغير)
        FloatingActionButton.small(
          heroTag: 'passenger_nearest_bus',
          onPressed: onNearestBus,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F766E),
          elevation: 3,
          tooltip: 'أقرب باص',
          child: findingNearest
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.near_me_rounded, size: 20),
        ),
        const SizedBox(height: 10),

        // 4) موقعي
        FloatingActionButton(
          heroTag: 'passenger_my_location',
          onPressed: onMyLocation,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryColor,
          elevation: 4,
          shape: const CircleBorder(),
          tooltip: 'موقعي',
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

        // إعدادات الطبقات — اختياري وصغير إن وُجد
        if (onMapLayers != null) ...[
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'passenger_map_layers',
            onPressed: onMapLayers,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textColor,
            elevation: 2,
            tooltip: 'طبقات الخريطة',
            child: const Icon(Icons.layers_outlined, size: 20),
          ),
        ],
      ],
    );
  }
}
