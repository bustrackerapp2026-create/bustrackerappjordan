import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pickup_label_size_setting.dart';
import '../../l10n/app_localizations.dart';

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
      final l10n = AppLocalizations.of(context);

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.mapLayersSettings,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    l10n.chooseMapStyle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStyleOption(
                        title: l10n.mapStyleStreets,
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
                        title: l10n.mapStyleSatellite,
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
                        title: l10n.mapStyleOutdoors,
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
                  Text(
                    l10n.customizeLabels,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    l10n.labelsHideHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.placeLabels),
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
                    title: Text(l10n.poiLabels),
                    subtitle: Text(l10n.poiLabelsSubtitle),
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
                    title: Text(l10n.roadLabels),
                    value: localRoad,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      localRoad = val;
                      onToggleRoadLabels(val);
                      setSheetState(() {});
                      onApplyFilters();
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.pickupLabelSizeTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.pickupLabelSizeHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  const PickupLabelSizePicker(),
                ],
              ),
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
                color:
                    isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                size: 22),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color:
                    isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
