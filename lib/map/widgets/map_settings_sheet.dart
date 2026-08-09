import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../core/theme/app_theme.dart';

void showMapSettingsSheet({
  required BuildContext context,
  required String currentStyle,
  required bool showPlaceLabels,
  required bool showPoiLabels,
  required bool showRoadLabels,
  required Function(String) onStyleChanged,
  required VoidCallback onApplyFilters,
  required ValueChanged<bool> onTogglePlaceLabels,
  required ValueChanged<bool> onTogglePoiLabels,
  required ValueChanged<bool> onToggleRoadLabels,
}) {
  // نسخ محلية تتحدث فوراً داخل الورقة (مثل خريطة الأدمن)
  String localStyle = currentStyle;
  bool localPlace = showPlaceLabels;
  bool localPoi = showPoiLabels;
  bool localRoad = showRoadLabels;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⚙️ إعدادات طبقات الخريطة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                const Text('اختر ستايل المظهر:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStyleOption(
                      title: 'شوارع',
                      icon: Icons.map,
                      styleUri: MapboxStyles.MAPBOX_STREETS,
                      currentStyle: localStyle,
                      onTap: (uri) {
                        localStyle = uri;
                        onStyleChanged(uri);
                        setSheetState(() {});
                      },
                    ),
                    _buildStyleOption(
                      title: 'قمر صناعي',
                      icon: Icons.satellite_alt,
                      styleUri: MapboxStyles.SATELLITE_STREETS,
                      currentStyle: localStyle,
                      onTap: (uri) {
                        localStyle = uri;
                        onStyleChanged(uri);
                        setSheetState(() {});
                      },
                    ),
                    _buildStyleOption(
                      title: 'طبيعة',
                      icon: Icons.landscape,
                      styleUri: MapboxStyles.OUTDOORS,
                      currentStyle: localStyle,
                      onTap: (uri) {
                        localStyle = uri;
                        onStyleChanged(uri);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('تخصيص الأسماء والمعالم:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'عند الإيقاف تختفي التسميات من الخريطة فوراً',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('📍 المدن والأماكن الكبرى'),
                  value: localPlace,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (val) {
                    localPlace = val;
                    onTogglePlaceLabels(val);
                    setSheetState(() {});
                    onApplyFilters();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('🏛️ معالم الجذب (POI)'),
                  subtitle: const Text('مطاعم، مستشفيات، مدارس...'),
                  value: localPoi,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (val) {
                    localPoi = val;
                    onTogglePoiLabels(val);
                    setSheetState(() {});
                    onApplyFilters();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('🛣️ أسماء الشوارع'),
                  value: localRoad,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (val) {
                    localRoad = val;
                    onToggleRoadLabels(val);
                    setSheetState(() {});
                    onApplyFilters();
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildStyleOption({
  required String title,
  required IconData icon,
  required String styleUri,
  required String currentStyle,
  required Function(String) onTap,
}) {
  final isSelected = currentStyle == styleUri;
  return SizedBox(
    width: 90,
    child: InkWell(
      onTap: () => onTap(styleUri),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                size: 22),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
