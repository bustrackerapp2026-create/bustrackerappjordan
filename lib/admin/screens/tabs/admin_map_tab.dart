import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/map/map_utils.dart';
import 'mixins/map_core_mixin.dart';
import 'mixins/driver_manager_mixin.dart';
import 'mixins/passenger_manager_mixin.dart';
import 'mixins/route_manager_mixin.dart';

class AdminMapTab extends StatefulWidget {
  const AdminMapTab({super.key});

  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab>
    with
        MapCoreMixin<AdminMapTab>,
        DriverManagerMixin<AdminMapTab>,
        PassengerManagerMixin<AdminMapTab>,
        RouteManagerMixin<AdminMapTab> {
  @override
  void initState() {
    super.initState();
    MapUtils.log('✅ AdminMapTab: بدء التهيئة', tag: 'AdminMap');
    listenToActiveDrivers();
    listenToActivePassengers();
    listenToRoutes();
  }

  @override
  void dispose() {
    disposeDrivers();
    disposePassengers();
    disposeRoutes();
    super.dispose();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;
    String? selectedDriverId;
    for (final entry in driverAnnotations.entries) {
      if (entry.value.id == annotation.id) {
        selectedDriverId = entry.key;
        break;
      }
    }
    if (selectedDriverId != null) {
      _showDriverDetailsBottomSheet(selectedDriverId);
    }
  }

  void _showDriverDetailsBottomSheet(String driverId) {
    if (!mounted) return;
    MapUtils.showSnackBar(
      context,
      '🔄 جاري تحميل بيانات السائق (ID: $driverId)...',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        buildMapWidget(key: const ValueKey('admin_map_widget')),
        if (!isMapReady) const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 30,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'admin_passengers_toggle',
            onPressed: togglePassengersVisibility,
            backgroundColor:
                showPassengers ? Colors.blue.shade700 : Colors.grey,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: Icon(
              showPassengers ? Icons.person : Icons.person_off,
              size: 26,
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_layers_fab',
            onPressed: () => showMapSettingsSheet(context),
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
