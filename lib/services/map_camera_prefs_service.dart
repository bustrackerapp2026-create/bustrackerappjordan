import 'package:shared_preferences/shared_preferences.dart';

import '../core/map/map_constants.dart';

/// آخر موضع كاميرا الخريطة (لكل دور: أدمن / راكب / سائق).
class MapCameraSnapshot {
  final double latitude;
  final double longitude;
  final double zoom;
  final double bearing;

  const MapCameraSnapshot({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    this.bearing = 0,
  });
}

class MapCameraPrefsService {
  MapCameraPrefsService._();
  static final MapCameraPrefsService instance = MapCameraPrefsService._();
  factory MapCameraPrefsService() => instance;

  static const roleAdmin = 'admin';
  static const rolePassenger = 'passenger';
  static const roleDriver = 'driver';

  String _prefix(String role) => 'map_cam_$role';

  Future<MapCameraSnapshot?> load(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = _prefix(role);
      if (!prefs.containsKey('${p}_lat') || !prefs.containsKey('${p}_lng')) {
        return null;
      }
      final lat = prefs.getDouble('${p}_lat');
      final lng = prefs.getDouble('${p}_lng');
      if (lat == null || lng == null) return null;
      if (lat < MapConstants.minLat ||
          lat > MapConstants.maxLat ||
          lng < MapConstants.minLng ||
          lng > MapConstants.maxLng) {
        return null;
      }
      final zoom = (prefs.getDouble('${p}_zoom') ?? MapConstants.cityZoom)
          .clamp(MapConstants.minZoom, MapConstants.maxZoom);
      final bearing = prefs.getDouble('${p}_bearing') ?? 0;
      return MapCameraSnapshot(
        latitude: lat,
        longitude: lng,
        zoom: zoom.toDouble(),
        bearing: bearing,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    String role, {
    required double latitude,
    required double longitude,
    required double zoom,
    double bearing = 0,
  }) async {
    if (latitude < MapConstants.minLat ||
        latitude > MapConstants.maxLat ||
        longitude < MapConstants.minLng ||
        longitude > MapConstants.maxLng) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = _prefix(role);
      await prefs.setDouble('${p}_lat', latitude);
      await prefs.setDouble('${p}_lng', longitude);
      await prefs.setDouble(
        '${p}_zoom',
        zoom.clamp(MapConstants.minZoom, MapConstants.maxZoom),
      );
      await prefs.setDouble('${p}_bearing', bearing);
    } catch (_) {}
  }
}
