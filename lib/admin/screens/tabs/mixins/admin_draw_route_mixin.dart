import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_core.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../models/planned_route.dart';
import '../../../../models/route_point.dart';
import '../../../../services/route_plan_service.dart';

/// الأدمن يرسم مساراً بالنقر على الخريطة ثم يسمّيه ويحفظه.
mixin AdminDrawRouteMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _drawRouteService = RoutePlanService();

  bool isDrawingRoute = false;
  final List<RoutePoint> _drawPoints = [];
  PolylineAnnotation? _drawLine;
  final List<PointAnnotation> _drawPointMarkers = [];

  void startDrawingRoute() {
    setState(() {
      isDrawingRoute = true;
      _drawPoints.clear();
    });
    unawaited(_clearDrawVisuals());
    MapUtils.showSnackBar(
      context,
      '🖊️ وضع الرسم: انقر على الخريطة لإضافة نقاط المسار',
    );
  }

  Future<void> cancelDrawingRoute() async {
    setState(() {
      isDrawingRoute = false;
      _drawPoints.clear();
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

  Future<void> onDrawRouteMapTap(Point point) async {
    if (!isDrawingRoute || !mounted) return;

    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();
    _drawPoints.add(RoutePoint(latitude: lat, longitude: lng));

    // علامة النقطة
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

    await _redrawDrawLine();
    if (mounted) setState(() {});
  }

  Future<void> _redrawDrawLine() async {
    if (polylineAnnotationManager == null || _drawPoints.length < 2) return;
    final coords =
        _drawPoints.map((p) => Position(p.longitude, p.latitude)).toList();
    try {
      if (_drawLine != null) {
        _drawLine!.geometry = LineString(coordinates: coords);
        await polylineAnnotationManager!.update(_drawLine!);
      } else {
        _drawLine = await polylineAnnotationManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: const Color(0xFF7C3AED).toARGB32(),
            lineWidth: 5,
            lineOpacity: 0.9,
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
    if (_drawPointMarkers.isNotEmpty) {
      final last = _drawPointMarkers.removeLast();
      try {
        await pointAnnotationManager?.delete(last);
      } catch (_) {}
    }
    if (_drawPoints.length < 2) {
      if (_drawLine != null) {
        try {
          await polylineAnnotationManager?.delete(_drawLine!);
        } catch (_) {}
        _drawLine = null;
      }
    } else {
      await _redrawDrawLine();
    }
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

    final result = await showModalBottomSheet<({String name, RouteDirection dir})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SaveDrawnRouteSheet(pointCount: _drawPoints.length),
    );
    if (result == null || !mounted) return;

    try {
      final saved = await _drawRouteService.saveAdminDrawnRoute(
        adminId: adminId,
        lineName: result.name,
        direction: result.dir,
        points: List<RoutePoint>.from(_drawPoints),
      );
      if (!mounted) return;
      setState(() {
        isDrawingRoute = false;
        _drawPoints.clear();
      });
      await _clearDrawVisuals();
      if (!mounted) return;
      final km = ((saved.distanceMeters ?? 0) / 1000).toStringAsFixed(1);
      MapUtils.showSnackBar(
        context,
        '✅ تم تخزين مسار ${result.dir.labelAr} «${result.name}» ($km كم)',
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
    _drawLine = null;
    _drawPointMarkers.clear();
    isDrawingRoute = false;
  }
}

class _SaveDrawnRouteSheet extends StatefulWidget {
  final int pointCount;
  const _SaveDrawnRouteSheet({required this.pointCount});

  @override
  State<_SaveDrawnRouteSheet> createState() => _SaveDrawnRouteSheetState();
}

class _SaveDrawnRouteSheetState extends State<_SaveDrawnRouteSheet> {
  final _nameCtrl = TextEditingController();
  RouteDirection _dir = RouteDirection.outbound;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'حفظ المسار المرسوم',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.pointCount} نقطة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم الخط *',
              hintText: 'مثال: عمان - الجيزة',
              border: OutlineInputBorder(),
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
              Navigator.pop(context, (name: name, dir: _dir));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'حفظ المسار',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
