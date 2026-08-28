import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

// CRITICAL: This was truncated during automated push.
// Restore full file from commit 0b369838d55bde7c54331637e17a762b69cad05b
// curl -sL "https://raw.githubusercontent.com/bustrackerapp2026-create/bustrackerappjordan/0b369838d55bde7c54331637e17a762b69cad05b/lib/passenger/screens/tabs/map_tab.dart" -o lib/passenger/screens/tabs/map_tab.dart

class MapTab extends StatefulWidget {
  const MapTab({super.key});
  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'map_tab.dart needs restore — see comment at top of file',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
