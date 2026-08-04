import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../map/utils/map_helpers.dart';

// ─── Logger مخصص للتطوير ──────────────────────────────────────────
void _log(String message) {
  if (kDebugMode) {
    debugPrint('📌 [AdminMap] $message');
  }
}

// ─── نموذج بيانات السائق (Enterprise Data Model) ──────────────────
class DriverLocationData {
  final String id;
  final String fullName;
  final double latitude;
  final double longitude;
  final bool isOnline;
  final String? busNumber;
  final String? route;
  final String? phoneNumber;
  final DateTime? lastUpdated;

  const DriverLocationData({
    required this.id,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    this.busNumber,
    this.route,
    this.phoneNumber,
    this.lastUpdated,
  });

  factory DriverLocationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DriverLocationData(
      id: doc.id,
      fullName: data['fullName'] as String? ?? 'سائق',
      latitude: (data['currentLatitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['currentLongitude'] as num?)?.toDouble() ?? 0.0,
      isOnline: data['isOnline'] as bool? ?? false,
      busNumber: data['busNumber'] as String?,
      route: data['route'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
}

// ─── الشاشة الرئيسية ──────────────────────────────────────────────
class AdminMapTab extends StatefulWidget {
  const AdminMapTab({super.key});

  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;

  // ✅ إدارة العلامات والاشتراكات لمنع تسرب الذاكرة
  final Map<String, PointAnnotation> _driverAnnotations = {};
  final Map<String, Uint8List> _driverMarkerCache = {};
  StreamSubscription<QuerySnapshot>? _driversSubscription;

  // إعدادات المظهر والطبقات
  bool _showPlaceLabels = true;
  bool _showPoiLabels = true;
  bool _showRoadLabels = true;
  String _currentMapStyle = MapboxStyles.MAPBOX_STREETS;
  bool _isMapReady = false;

  // ─── حدود جغرافية (الأردن) ────────────────────────────────────────
  static const double _minLat = 29.1;
  static const double _maxLat = 33.4;
  static const double _minLng = 34.8;
  static const double _maxLng = 39.2;

  @override
  void initState() {
    super.initState();
    _log('✅ AdminMapTab: بدء التهيئة');
    _listenToActiveDrivers();
  }

  @override
  void dispose() {
    // ✅ تنظيف كلي للموارد والاشتراكات عند إغلاق الشاشة
    _driversSubscription?.cancel();
    if (_pointAnnotationManager != null && _mapboxMap != null) {
      _mapboxMap?.annotations.removeAnnotationManager(_pointAnnotationManager!);
    }
    _pointAnnotationManager = null;
    _driverAnnotations.clear();
    _driverMarkerCache.clear();
    super.dispose();
  }

  // ─── الاستماع للسائقين النشطين (تحسين استعلام Firestore) ──────────
  void _listenToActiveDrivers() {
    _driversSubscription?.cancel();

    // ✅ فلترة السائقين النشطين والموثقين والمتصلين فقط
    _driversSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('userType', isEqualTo: 'driver')
        .where('isVerified', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _log('📦 تم استلام ${snapshot.docs.length} سائق نشط من Firestore');
      _updateDriverMarkers(snapshot);
    }, onError: (error) {
      _log('❌ خطأ في جلب بيانات السائقين: $error');
    });
  }

  // ─── تحديث العلامات على الخريطة ──────────────────────────────────
  Future<void> _updateDriverMarkers(QuerySnapshot snapshot) async {
    if (_pointAnnotationManager == null || !mounted) return;

    final newDriverIds = snapshot.docs.map((doc) => doc.id).toSet();
    final currentDriverIds = _driverAnnotations.keys.toSet();
    final driversToRemove = currentDriverIds.difference(newDriverIds);

    // 1. إزالة العلامات التي أصبحت غير نشطة
    for (final driverId in driversToRemove) {
      final annotation = _driverAnnotations[driverId];
      if (annotation != null) {
        await _pointAnnotationManager?.delete(annotation);
        _driverAnnotations.remove(driverId);
      }
    }

    // 2. إنشاء أو تحديث مواضع العلامات الحالية
    for (final doc in snapshot.docs) {
      final driver = DriverLocationData.fromFirestore(doc);

      if (driver.latitude == 0.0 || driver.longitude == 0.0) continue;

      await _createOrUpdateMarker(
        driverId: driver.id,
        lat: driver.latitude,
        lng: driver.longitude,
        name: driver.fullName,
        isOnline: driver.isOnline,
      );
    }
  }

  // ─── إضافة / تحديث علامة موقع ───────────────────────────────────
  Future<void> _createOrUpdateMarker({
    required String driverId,
    required double lat,
    required double lng,
    required String name,
    required bool isOnline,
  }) async {
    if (_pointAnnotationManager == null || !mounted) return;

    final point = Point(coordinates: Position(lng, lat));

    // تحديث موقع العلامة إذا كانت موجودة
    if (_driverAnnotations.containsKey(driverId)) {
      final annotation = _driverAnnotations[driverId]!;
      annotation.geometry = point;
      await _pointAnnotationManager?.update(annotation);
      return;
    }

    // إنشاء صورة رسم العلامة
    final markerBytes =
        await _createDriverMarkerImage(name: name, isOnline: isOnline);
    if (markerBytes == null || !mounted) return;

    final options = PointAnnotationOptions(
      geometry: point,
      image: markerBytes,
      iconSize: 1.0,
      iconAnchor: IconAnchor.BOTTOM,
    );

    final annotation = await _pointAnnotationManager?.create(options);
    if (annotation != null) {
      _driverAnnotations[driverId] = annotation;
    }
  }

  // ─── رسم صورة العلامة المخصصة (Canvas Custom Drawing) ─────────────
  Future<Uint8List?> _createDriverMarkerImage({
    required String name,
    required bool isOnline,
  }) async {
    final cacheKey = '${name}_${isOnline ? '1' : '0'}';
    if (_driverMarkerCache.containsKey(cacheKey)) {
      return _driverMarkerCache[cacheKey];
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 80.0;
      const center = Offset(size / 2, size / 2);

      canvas.drawColor(Colors.transparent, BlendMode.clear);

      // رسم الهالة المتوهجة
      final glowColor = isOnline ? Colors.green : Colors.grey;
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawCircle(center, 22, glowPaint);

      // الدائرة الخارجية
      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 16, outerPaint);

      // الدائرة الداخلية
      final innerPaint = Paint()
        ..color = isOnline ? Colors.green.shade600 : Colors.grey.shade600
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12, innerPaint);

      // أيقونة باص
      final busPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final busPath = Path();
      const centerX = size / 2;
      const centerY = size / 2;

      busPath.addRect(Rect.fromCenter(
        center: const Offset(centerX, centerY + 2),
        width: 14,
        height: 10,
      ));
      busPath.addOval(Rect.fromCenter(
        center: const Offset(centerX - 5, centerY + 8),
        width: 4,
        height: 4,
      ));
      busPath.addOval(Rect.fromCenter(
        center: const Offset(centerX + 5, centerY + 8),
        width: 4,
        height: 4,
      ));
      canvas.drawPath(busPath, busPaint);

      // كتابة اسم السائق أسفل العلامة
      final textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: size);
      textPainter.paint(
        canvas,
        Offset((size - textPainter.width) / 2, size - 14),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      _driverMarkerCache[cacheKey] = bytes;
      return bytes;
    } catch (e) {
      _log('⚠️ خطأ أثناء رسم صورة العلامة: $e');
      return null;
    }
  }

  // ─── تقييد حدود الكاميرا بالحدود الجغرافية للدولة ──────────────────
  void _applyMapConstraints() {
    if (_mapboxMap == null) return;

    try {
      // ✅ تصحيح البرامتر المطلوب infiniteBounds: false
      _mapboxMap?.setBounds(
        CameraBoundsOptions(
          bounds: CoordinateBounds(
            southwest: Point(coordinates: Position(_minLng, _minLat)),
            northeast: Point(coordinates: Position(_maxLng, _maxLat)),
            infiniteBounds: false,
          ),
        ),
      );
      _log('✅ تم تحديد حدود الكاميرا بنجاح');
    } catch (e) {
      _log('⚠️ خطأ في تطبيق حدود الكاميرا: $e');
    }
  }

  // ─── تهيئة وإدارة محرك العلامات ────────────────────────────────
  Future<void> _initAnnotationManager() async {
    if (_mapboxMap == null) return;

    try {
      if (_pointAnnotationManager != null) {
        await _mapboxMap?.annotations
            .removeAnnotationManager(_pointAnnotationManager!);
        _pointAnnotationManager = null;
      }

      _driverAnnotations.clear();
      _pointAnnotationManager =
          await _mapboxMap?.annotations.createPointAnnotationManager();

      if (_pointAnnotationManager != null) {
        // ✅ استخدام tapEvents الحديث وفقاً لإصدار Mapbox v2.10+
        _pointAnnotationManager!.tapEvents(
          onTap: (annotation) {
            _log('📍 تم النقر على العلامة: ${annotation.id}');
            _handleAnnotationTap(annotation);
          },
        );
        _log('✅ مدير العلامات جاهز ومستعد للأحداث');
      }
    } catch (e) {
      _log('❌ خطأ في تهيئة PointAnnotationManager: $e');
    }
  }

  // ─── التعامل مع حدث النقر على السائق ─────────────────────────────
  void _handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;

    String? selectedDriverId;
    for (final entry in _driverAnnotations.entries) {
      if (entry.value.id == annotation.id) {
        selectedDriverId = entry.key;
        break;
      }
    }

    if (selectedDriverId != null) {
      _showDriverDetailsBottomSheet(selectedDriverId);
    }
  }

  // ─── عرض تفاصيل السائق عند الضغط ──────────────────────────────────
  void _showDriverDetailsBottomSheet(String driverId) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔄 جاري تحميل بيانات السائق (ID: $driverId)...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── دوال تخصيص طبقات وستايل الخريطة ─────────────────────────────
  Future<void> _applyLabelLayersFilter() async {
    if (_mapboxMap == null) return;
    await MapHelpers.applyLabelLayersFilter(
      mapboxMap: _mapboxMap!,
      showPlaceLabels: _showPlaceLabels,
      showPoiLabels: _showPoiLabels,
      showRoadLabels: _showRoadLabels,
    );
  }

  Future<void> _changeMapStyle(String styleUri) async {
    if (_mapboxMap == null) return;
    try {
      setState(() => _currentMapStyle = styleUri);
      await _mapboxMap?.loadStyleURI(styleUri);
      await _initAnnotationManager();
      await _applyLabelLayersFilter();
      _applyMapConstraints();
    } catch (e) {
      _log('⚠️ خطأ أثناء تغيير مظهر الخريطة: $e');
    }
  }

  // ─── واجهة المستخدم (UI) ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('admin_map_widget'),
          onMapCreated: (map) {
            _mapboxMap = map;
            _initAnnotationManager();
            _applyMapConstraints();
            _mapboxMap?.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(35.9106, 31.9522)),
                zoom: 8.5,
              ),
            );
            _applyLabelLayersFilter();
            if (mounted) {
              setState(() => _isMapReady = true);
            }
            _log('✅ تم إنشاء الخريطة بنجاح');
          },
          styleUri: _currentMapStyle,
        ),

        // مؤشر التحميل الأولي عند بدء الخريطة
        if (!_isMapReady)
          const Center(
            child: CircularProgressIndicator(),
          ),

        // زر التعديل على طبقات الخريطة
        Positioned(
          bottom: 30,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_layers_fab',
            onPressed: _showMapSettingsSheet,
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

  // ─── القائمة السفلية لإعدادات الخريطة ─────────────────────────────
  void _showMapSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '⚙️ إعدادات طبقات الخريطة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'اختر ستايل المظهر:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStyleOption(
                        title: 'شوارع',
                        icon: Icons.map_outlined,
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                        setSheetState: setSheetState,
                      ),
                      _buildStyleOption(
                        title: 'قمر صناعي',
                        icon: Icons.satellite_alt_outlined,
                        styleUri: MapboxStyles.SATELLITE_STREETS,
                        setSheetState: setSheetState,
                      ),
                      _buildStyleOption(
                        title: 'طبيعة',
                        icon: Icons.landscape_outlined,
                        styleUri: MapboxStyles.OUTDOORS,
                        setSheetState: setSheetState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'تخصيص الأسماء والمعالم:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('📍 المدن والأماكن الكبرى'),
                    value: _showPlaceLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      setState(() => _showPlaceLabels = val);
                      setSheetState(() {});
                      _applyLabelLayersFilter();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('🏛️ معالم الجذب (POI)'),
                    value: _showPoiLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      setState(() => _showPoiLabels = val);
                      setSheetState(() {});
                      _applyLabelLayersFilter();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('🛣️ أسماء الشوارع'),
                    value: _showRoadLabels,
                    activeThumbColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      setState(() => _showRoadLabels = val);
                      setSheetState(() {});
                      _applyLabelLayersFilter();
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

  // ─── عنصر خيار الستايل ─────────────────────────────────────────
  Widget _buildStyleOption({
    required String title,
    required IconData icon,
    required String styleUri,
    required StateSetter setSheetState,
  }) {
    final isSelected = _currentMapStyle == styleUri;
    return SizedBox(
      width: 95,
      child: InkWell(
        onTap: () {
          setSheetState(() {});
          _changeMapStyle(styleUri);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              Icon(
                icon,
                color:
                    isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
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
}
