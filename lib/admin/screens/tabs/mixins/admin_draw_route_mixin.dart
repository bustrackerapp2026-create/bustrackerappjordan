import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
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

/// رسم مسار أدمن مع لصق حي على الشبكة الطرقية (نقطة → شارع → Directions).
mixin AdminDrawRouteMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final RoutePlanService _drawRouteService = RoutePlanService();

  bool isDrawingRoute = false;
  bool isSnappingSegment = false;

  /// نقاط التحكم بعد لصقها على الشارع
  final List<RoutePoint> _drawPoints = [];

  /// هندسة الطريق لكل قطعة بين نقطتي تحكم
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
      '🖊️ انقر قرب الشارع — تُلصق النقطة ثم يُرسم المسار كقيادة حقيقية',
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
    for (final seg in _roadSegments) {
      if (seg.isEmpty) continue;
      if (out.isEmpty) {
        out.addAll(seg);
      } else {
        out.addAll(seg.skip(1));
      }
    }
    return out;
  }

  Future<void> onDrawRouteMapTap(Point point) async {
    if (!isDrawingRoute || !mounted || isSnappingSegment) return;

    final raw = RoutePoint(
      latitude: point.coordinates.lat.toDouble(),
      longitude: point.coordinates.lng.toDouble(),
    );

    if (mounted) setState(() => isSnappingSegment = true);

    try {
      final snapped = await _drawRouteService.snapPointToRoad(raw);

      if (_drawPoints.isNotEmpty) {
        final last = _drawPoints.last;
        final d = _meters(
          last.latitude,
          last.longitude,
          snapped.latitude,
          snapped.longitude,
        );
        if (d < 15) {
          if (mounted) {
            MapUtils.showSnackBar(
              context,
              'النقطة قريبة جداً من السابقة — انقر أبعد قليلاً',
              isError: true,
            );
          }
          return;
        }
      }

      _drawPoints.add(snapped);

      try {
        final manager = pointAnnotationManager;
        if (manager != null) {
          final ann = await manager.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(snapped.longitude, snapped.latitude),
              ),
              iconSize: 0.75,
              iconColor: const Color(0xFF7C3AED).toARGB32(),
            ),
          );
          _drawPointMarkers.add(ann);
        }
      } catch (_) {}

      if (_drawPoints.length >= 2) {
        final from = _drawPoints[_drawPoints.length - 2];
        final to = _drawPoints.last;
        final road = await _drawRouteService.getDrivingPath(
          from: from,
          to: to,
          snapEndpoints: false,
        );
        _roadSegments.add(road.length >= 2 ? road : [from, to]);
      }

      await _redrawDrawLine();
    } catch (e) {
      MapUtils.log('draw tap snap: $e', tag: 'AdminDraw');
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          'تعذر لصق النقطة على الشارع — حاول مرة أخرى',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => isSnappingSegment = false);
    }
  }

  double _meters(double lat1, double lng1, double lat2, double lng2) {
    const earth = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double d) => d * math.pi / 180;

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
            lineWidth: 6.0,
            lineOpacity: 0.95,
          ),
        );
      }
    } catch (e) {
      MapUtils.log('admin draw line: $e', tag: 'AdminDraw');
    }
  }

  Future<void> undoLastDrawPoint() async {
    if (_drawPoints.isEmpty || isSnappingSegment) return;
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

  String _friendlySaveError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'رفض Firebase الكتابة على plannedRoutes. '
              'انشر قواعد Firestore من المشروع (firebase deploy --only firestore) '
              'وتأكد أن حسابك userType = admin في مجموعة users.';
        case 'failed-precondition':
          return 'فهرس Firestore ناقص لاستعلام المسارات. '
              'انشر الفهارس: firebase deploy --only firestore:indexes';
        case 'unavailable':
          return 'تعذر الاتصال بـ Firebase — تحقق من الإنترنت وحاول مجدداً.';
        default:
          return 'خطأ Firebase (${e.code}): ${e.message ?? e}';
      }
    }
    final s = e.toString();
    if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
      return 'رفض الصلاحيات على plannedRoutes — انشر firestore.rules ثم أعد المحاولة.';
    }
    return s;
  }

  Future<void> finishAndSaveDrawnRoute() async {
    if (!mounted || isSnappingSegment) return;
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
    if (adminId == null) {
      MapUtils.showSnackBar(
        context,
        'يجب تسجيل الدخول كأدمن قبل الحفظ',
        isError: true,
      );
      return;
    }

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
      MapUtils.showSnackBar(
        context,
        'جاري تحسين المسار على الشوارع والجسور ثم الحفظ…',
      );

      final control = List<RoutePoint>.from(_drawPoints);

      final saved = await _drawRouteService.saveAdminDrawnRoute(
        adminId: adminId,
        lineName: result.name,
        direction: result.dir,
        points: control,
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
      MapUtils.log('save drawn route: $e', tag: 'AdminDraw');
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          '❌ ${_friendlySaveError(e)}',
          isError: true,
        );
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
