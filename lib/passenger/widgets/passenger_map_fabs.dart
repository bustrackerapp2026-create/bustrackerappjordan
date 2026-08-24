import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// أزرار خريطة الراكب.
///
/// - الأزرار النصية (باصات من هنا / إلى أين؟) فوق
/// - عمود الأيقونات الثلاث ملتصق بأقصى يمين الشاشة (جهة بداية العربية)
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
        _PrimaryChip(
          heroTag: 'passenger_nearby_buses',
          onPressed: findingNearby ? null : onNearbyBuses,
          loading: findingNearby,
          active: nearbyModeActive,
          activeColor: const Color(0xFF0F766E),
          color: const Color(0xFF0D9488),
          icon: nearbyModeActive
              ? Icons.alt_route_rounded
              : Icons.hail_rounded,
          label: nearbyModeActive ? 'خطوط موقعي' : 'باصات من هنا',
        ),
        const SizedBox(height: 10),
        _PrimaryChip(
          heroTag: 'passenger_destination',
          onPressed: onSetDestination,
          loading: false,
          active: hasDestination,
          activeColor: const Color(0xFF6D28D9),
          color: Colors.white,
          foreground: hasDestination ? Colors.white : const Color(0xFF6D28D9),
          icon: hasDestination ? Icons.flag_rounded : Icons.flag_outlined,
          label: hasDestination ? 'تغيير الوجهة' : 'إلى أين؟',
          outlined: !hasDestination,
        ),
        const SizedBox(height: 12),
        // عمود عمودي: أقرب باص · موقعي · طبقات — أقصى اليمين
        Material(
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.22),
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundAction(
                  heroTag: 'passenger_nearest_bus',
                  tooltip: 'أقرب باص',
                  onPressed: onNearestBus,
                  color: const Color(0xFF0F766E),
                  loading: findingNearest,
                  icon: Icons.near_me_rounded,
                ),
                const SizedBox(height: 8),
                _RoundAction(
                  heroTag: 'passenger_my_location',
                  tooltip: 'موقعي',
                  onPressed: onMyLocation,
                  color: AppTheme.primaryColor,
                  loading: isLoadingPassengerLocation,
                  icon: Icons.my_location_rounded,
                  large: true,
                ),
                if (onMapLayers != null) ...[
                  const SizedBox(height: 8),
                  _RoundAction(
                    heroTag: 'passenger_map_layers',
                    tooltip: 'طبقات الخريطة',
                    onPressed: onMapLayers,
                    color: const Color(0xFF5F6368),
                    loading: false,
                    icon: Icons.layers_outlined,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryChip extends StatelessWidget {
  final String heroTag;
  final VoidCallback? onPressed;
  final bool loading;
  final bool active;
  final Color color;
  final Color activeColor;
  final Color? foreground;
  final IconData icon;
  final String label;
  final bool outlined;

  const _PrimaryChip({
    required this.heroTag,
    required this.onPressed,
    required this.loading,
    required this.active,
    required this.color,
    required this.activeColor,
    required this.icon,
    required this.label,
    this.foreground,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? activeColor : color;
    final fg = foreground ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: outlined ? 3 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: outlined
              ? BorderSide(color: fg.withValues(alpha: 0.25))
              : BorderSide.none,
        ),
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final String heroTag;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final bool loading;
  final IconData icon;
  final bool large;

  const _RoundAction({
    required this.heroTag,
    required this.tooltip,
    required this.onPressed,
    required this.color,
    required this.loading,
    required this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 48.0 : 40.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: large ? 22 : 18,
                      height: large ? 22 : 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: large ? 24 : 20),
            ),
          ),
        ),
      ),
    );
  }
}
