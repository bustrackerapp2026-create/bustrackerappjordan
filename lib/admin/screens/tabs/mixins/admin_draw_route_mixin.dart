import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../models/planned_route.dart';
import '../../../../models/route_point.dart';
import '../../../../services/route_plan_service.dart';

/// الأدمن يرسم مساراً بالنقر؛ كل قطعة تُلصق على الشوارع عبر Mapbox Directions.
mixin AdminDrawRouteMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _drawRouteService = RoutePlanService();

  bool isDrawingRoute = false;
  bool isSnappingSegment = false;

  /// نقاط النقر (نقاط التحكم)
  final List<RoutePoint> _drawPoints = [];

  /// هندسة الطريق الفعلية لكل قطعة بين نقرتين
  final List<List<RoutePoint>> _roadSegments = [];

  PolylineAnnotation? _drawLine;
  final List<PointAnnotation> _drawPointMarkers = [];

  void startDrawingRoute() {
    setState(() {
      isDrawingRoute = true;
      isSnappingSegment = false;
      _drawPoints.clear();
      _roadSegments.clear();
    });
    unawaited(_clearDrawVisuals());
    MapUtils.showSnackBar(
      context,
      '🖊️ انقر على الشارع بالتسلسل — المسار يلتصق بالطرق والجسور',
    );
  }

  Future<void> cancelDrawingRoute() async {
    setState(() {
      isDrawingRoute = false;
      isSnappingSegment = false;
      _drawPoints.clear();
      _roadSegments.clear();
    });
    await _clearDrawVisuals();
    if (mounted) {
      MapUtils.showSnackBar(context, 'تم إلغاء رسم المسار');
    }
  }

  Future<void> _clearDrawVisuals() async {
    if (_drawLine != null && polylineAnnotationManager != null) {
      try {
        await polylineAnnotationManager!.delete(_drawLine!);
      } catch (_) {}
    }
    _drawLine = null;
    for (final m in _drawPointMarkers) {
      try {
        await pointAnnotationManager?.delete(m);
      } catch (_) {}
    }
    _drawPointMarkers.clear();
  }

  List<RoutePoint> get _flattenedRoadPath {
    if (_roadSegments.isEmpty) return List.of(_drawPoints);
    final out = <RoutePoint>[];
    for (var i = 0; i < _roadSegments.length; i++) {
      final seg = _roadSegments[i];
      if (seg.isEmpty) continue;
      if (out.isEmpty) {
        out.addAll(seg);
      } else {
        // تجنب تكرار نقطة الوصل
        out.addAll(seg.skip(1));
      }
    }
    return out;
  }

  Future<void> onDrawRouteMapTap(Point point) async {
    if (!isDrawingRoute || !mounted || isSnappingSegment) return;

    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();
    final tapped = RoutePoint(latitude: lat, longitude: lng);
    _drawPoints.add(tapped);

    // علامة نقطة التحكم
    try {
      final manager = pointAnnotationManager;
      if (manager != null) {
        final ann = await manager.create(
          PointAnnotationOptions(
            geometry: point,
            iconSize: 0.7,
            iconColor: const Color(0xFF7C3AED).toARGB32(),
          ),
        );
        _drawPointMarkers.add(ann);
      }
    } catch (_) {}

    if (_drawPoints.length >= 2) {
      if (mounted) setState(() => isSnappingSegment = true);
      try {
        final from = _drawPoints[_drawPoints.length - 2];
        final to = _drawPoints.last;
        final road = await _drawRouteService.getDrivingPath(from: from, to: to);
        _roadSegments.add(road.length >= 2 ? road : [from, to]);
      } catch (_) {
        final from = _drawPoints[_drawPoints.length - 2];
        final to = _drawPoints.last;
        _roadSegments.add([from, to]);
      } finally {
        if (mounted) setState(() => isSnappingSegment = false);
      }
    }

    await _redrawDrawLine();
    if (mounted) setState(() {});
  }

  Future<void> _redrawDrawLine() async {
    if (polylineAnnotationManager == null) return;
    final path = _flattenedRoadPath;
    if (path.length < 2) {
      if (_drawLine != null) {
        try {
          await polylineAnnotationManager?.delete(_drawLine!);
        } catch (_) {}
        _drawLine = null;
      }
      return;
    }

    final coords =
        path.map((p) => Position(p.longitude, p.latitude)).toList();
    try {
      if (_drawLine != null) {
        _drawLine!.geometry = LineString(coordinates: coords);
        await polylineAnnotationManager!.update(_drawLine!);
      } else {
        _drawLine = await polylineAnnotationManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: const Color(0xFF7C3AED).toARGB32(),
            lineWidth: 5.5,
            lineOpacity: 0.92,
          ),
        );
      }
    } catch (e) {
      MapUtils.log('admin draw line: $e', tag: 'AdminDraw');
    }
  }

  Future<void> undoLastDrawPoint() async {
    if (_drawPoints.isEmpty) return;
    _drawPoints.removeLast();
    if (_roadSegments.isNotEmpty) {
      _roadSegments.removeLast();
    }
    if (_drawPointMarkers.isNotEmpty) {
      final last = _drawPointMarkers.removeLast();
      try {
        await pointAnnotationManager?.delete(last);
      } catch (_) {}
    }
    await _redrawDrawLine();
    if (mounted) setState(() {});
  }

  Future<void> finishAndSaveDrawnRoute() async {
    if (!mounted) return;
    if (_drawPoints.length < 2) {
      MapUtils.showSnackBar(
        context,
        'أضف نقطتين على الأقل',
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final adminId = auth.userId;
    if (adminId == null) return;

    final result = await showModalBottomSheet<
        ({String name, RouteDirection dir, List<String> aliases})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SaveDrawnRouteSheet(
        pointCount: _drawPoints.length,
        roadPointCount: _flattenedRoadPath.length,
      ),
    );
    if (result == null || !mounted) return;

    try {
      MapUtils.showSnackBar(context, 'جاري لصق المسار على الشوارع وحفظه…');

      // إعادة بناء كاملة لضمان أفضل مسار، مع الاحتفاظ بهندسة الرسم كاحتياطي
      final control = List<RoutePoint>.from(_drawPoints);
      final livePath = _flattenedRoadPath;

      final saved = await _drawRouteService.saveAdminDrawnRoute(
        adminId: adminId,
        lineName: result.name,
        direction: result.dir,
        points: control.length >= 2 ? control : livePath,
        aliases: result.aliases,
        alreadySnapped: false,
      );

      if (!mounted) return;
      setState(() {
        isDrawingRoute = false;
        isSnappingSegment = false;
        _drawPoints.clear();
        _roadSegments.clear();
      });
      await _clearDrawVisuals();
      if (!mounted) return;
      final km = ((saved.distanceMeters ?? 0) / 1000).toStringAsFixed(1);
      MapUtils.showSnackBar(
        context,
        '✅ تم اعتماد مسار ${result.dir.labelAr} «${result.name}» '
        '($km كم · ${saved.points.length} نقطة شارع) للجميع',
      );
    } catch (e) {
      if (mounted) {
        MapUtils.showSnackBar(context, '❌ $e', isError: true);
      }
    }
  }

  int get drawPointCount => _drawPoints.length;

  void disposeAdminDrawRoute() {
    _drawPoints.clear();
    _roadSegments.clear();
    _drawLine = null;
    _drawPointMarkers.clear();
    isDrawingRoute = false;
    isSnappingSegment = false;
  }
}

class _SaveDrawnRouteSheet extends StatefulWidget {
  final int pointCount;
  final int roadPointCount;
  const _SaveDrawnRouteSheet({
    required this.pointCount,
    required this.roadPointCount,
  });

  @override
  State<_SaveDrawnRouteSheet> createState() => _SaveDrawnRouteSheetState();
}

class _SaveDrawnRouteSheetState extends State<_SaveDrawnRouteSheet> {
  final _nameCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  RouteDirection _dir = RouteDirection.outbound;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  List<String> get _suggestions => AppConstants.jordanRoutes;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'حفظ المسار المعتمد',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.pointCount} نقطة تحكم · ${widget.roadPointCount} نقطة شارع',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الخط *',
                hintText: 'مثال: عمان - الزرقاء',
                border: OutlineInputBorder(),
                helperText: 'يُحفظ معتمداً ويظهر للركاب فوراً',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestions.take(6).map((s) {
                return ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _nameCtrl.text = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'أسماء بديلة للبحث (اختياري)',
                hintText: 'الزرقاء عمان، خط الزرقاء…',
                border: OutlineInputBorder(),
                helperText: 'افصل بفاصلة — تساعد الراكب عند البحث التقريبي',
              ),
            ),
            const SizedBox(height: 12),
            const Text('الاتجاه', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SegmentedButton<RouteDirection>(
              segments: const [
                ButtonSegment(
                  value: RouteDirection.outbound,
                  label: Text('ذهاب'),
                ),
                ButtonSegment(
                  value: RouteDirection.returnTrip,
                  label: Text('إياب'),
                ),
              ],
              selected: {_dir},
              onSelectionChanged: (s) => setState(() => _dir = s.first),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) return;
                final aliases = _aliasCtrl.text
                    .split(RegExp(r'[,،]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                Navigator.pop(
                  context,
                  (name: name, dir: _dir, aliases: aliases),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'حفظ واعتماد على Firebase',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
