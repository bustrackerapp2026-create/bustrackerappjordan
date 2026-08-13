import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../../../core/map/map_utils.dart';
import '../../../../driver/providers/driver_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../models/planned_route.dart';
import '../../../../models/route_point.dart';
import '../../../../services/route_plan_service.dart';
import 'driver_location_mixin.dart';

/// تسجيل مسار خطة الخط (ذهاب / إياب) — مشترك باسم الخط.
mixin RoutePlanRecordingMixin<T extends StatefulWidget>
    on DriverLocationMixin<T> {
  final RoutePlanService _routePlanService = RoutePlanService();

  bool isRecordingRoutePlan = false;
  bool isSavingRoutePlan = false;
  RouteDirection? recordingDirection;
  final List<RoutePoint> _routePlanBuffer = [];

  PolylineAnnotationManager? _routePlanLineManager;
  PolylineAnnotation? _routePlanLine;

  /// مسارات الخط الحالي (مشتركة وليس لكل سائق)
  List<PlannedRoute> linePlannedRoutes = const [];
  StreamSubscription<List<PlannedRoute>>? _plannedRoutesSub;
  String? _listeningLineName;

  int get routePlanPointCount => _routePlanBuffer.length;

  /// توافق
  List<PlannedRoute> get driverPlannedRoutes => linePlannedRoutes;

  @override
  void onDriverPositionSample(geo.Position position) {
    appendRoutePlanPoint(position);
  }

  Future<void> initRoutePlanLayer() async {
    if (mapboxMap == null) return;
    _routePlanLineManager ??=
        await mapboxMap!.annotations.createPolylineAnnotationManager();
  }

  /// يستمع لمسارات الخط المختار (مشتركة بين كل الباصات)
  void listenLinePlannedRoutes(String lineName) {
    if (_listeningLineName == lineName) return;
    _listeningLineName = lineName;
    _plannedRoutesSub?.cancel();
    _plannedRoutesSub =
        _routePlanService.watchLineRoutes(lineName).listen((list) {
      linePlannedRoutes = list;
      if (mounted) setState(() {});
    });
  }

  @Deprecated('استخدم listenLinePlannedRoutes')
  void listenDriverPlannedRoutes(String driverId) {
    // لا شيء — المسارات مشتركة باسم الخط
  }

  PlannedRoute? plannedFor(RouteDirection d, String lineName) {
    for (final r in linePlannedRoutes) {
      if (r.direction == d && r.lineName == lineName) return r;
    }
    return null;
  }

  Future<void> startRoutePlanRecording({
    required RouteDirection direction,
    required String lineName,
  }) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) {
      MapUtils.showSnackBar(context, '⚠️ سجّل الدخول أولاً', isError: true);
      return;
    }

    final existing = plannedFor(direction, lineName);
    if (existing != null && existing.isLocked) {
      MapUtils.showSnackBar(
        context,
        'مسار ${direction.labelAr} لخط «$lineName» مخزّن مسبقاً. '
        'اطلب تعديلاً من الأدمن مع ذكر السبب إن لزم.',
        isError: true,
      );
      return;
    }

    final driver = context.read<DriverProvider>();
    if (driver.currentPosition == null) {
      MapUtils.showSnackBar(
        context,
        '⚠️ حدّد موقعك أولاً قبل تسجيل المسار',
        isError: true,
      );
      return;
    }

    if (!driver.isOnline) {
      MapUtils.showSnackBar(
        context,
        'فعّل الاتصال أولاً لتسجيل المسار بدقة',
        isError: true,
      );
      return;
    }

    await initRoutePlanLayer();

    setState(() {
      isRecordingRoutePlan = true;
      recordingDirection = direction;
      _routePlanBuffer
        ..clear()
        ..add(RoutePoint(
          latitude: driver.currentPosition!.latitude,
          longitude: driver.currentPosition!.longitude,
          timestamp: DateTime.now(),
        ));
    });

    await ensureDriverTrackingRunning();
    await _redrawRoutePlanLine();
    MapUtils.showSnackBar(
      context,
      '⏺ تسجيل ${direction.labelAr} — قُد على مسار الشارع ثم احفظ',
    );
  }

  void appendRoutePlanPoint(geo.Position pos) {
    if (!isRecordingRoutePlan) return;

    if (_routePlanBuffer.isNotEmpty) {
      final last = _routePlanBuffer.last;
      final dLat = (pos.latitude - last.latitude).abs();
      final dLng = (pos.longitude - last.longitude).abs();
      if (dLat < 0.00011 && dLng < 0.00011) return;
    }

    _routePlanBuffer.add(RoutePoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      speed: pos.speed,
      heading: pos.heading,
      accuracy: pos.accuracy,
    ));

    unawaited(_redrawRoutePlanLine());
    if (mounted && _routePlanBuffer.length % 8 == 0) {
      setState(() {});
    }
  }

  Future<void> _redrawRoutePlanLine() async {
    if (_routePlanLineManager == null || _routePlanBuffer.length < 2) return;

    final coords = _routePlanBuffer
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    try {
      if (_routePlanLine != null) {
        _routePlanLine!.geometry = LineString(coordinates: coords);
        await _routePlanLineManager!.update(_routePlanLine!);
      } else {
        _routePlanLine = await _routePlanLineManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: const Color(0xFF7C3AED).toARGB32(),
            lineWidth: 5,
            lineOpacity: 0.9,
          ),
        );
      }
    } catch (e) {
      MapUtils.log('route plan line: $e', tag: 'RoutePlan');
    }
  }

  Future<void> cancelRoutePlanRecording() async {
    setState(() {
      isRecordingRoutePlan = false;
      recordingDirection = null;
      _routePlanBuffer.clear();
    });
    await _clearRoutePlanLine();
    if (mounted) {
      MapUtils.showSnackBar(context, 'تم إلغاء تسجيل المسار');
    }
  }

  Future<void> _clearRoutePlanLine() async {
    if (_routePlanLine != null && _routePlanLineManager != null) {
      try {
        await _routePlanLineManager!.delete(_routePlanLine!);
      } catch (_) {}
    }
    _routePlanLine = null;
  }

  Future<void> saveRoutePlanRecording({required String lineName}) async {
    if (!mounted || isSavingRoutePlan) return;
    final direction = recordingDirection;
    if (direction == null) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) return;

    if (_routePlanBuffer.length < RoutePlanService.minPointsToSave) {
      MapUtils.showSnackBar(
        context,
        'المسار قصير جداً. أكمل القيادة على الخط ثم احفظ.',
        isError: true,
      );
      return;
    }

    setState(() => isSavingRoutePlan = true);
    try {
      final saved = await _routePlanService.saveRecordedRoute(
        driverId: uid,
        lineName: lineName,
        direction: direction,
        rawPoints: List<RoutePoint>.from(_routePlanBuffer),
      );

      if (!mounted) return;
      setState(() {
        isRecordingRoutePlan = false;
        recordingDirection = null;
        _routePlanBuffer.clear();
        isSavingRoutePlan = false;
      });
      await _clearRoutePlanLine();

      final km = ((saved.distanceMeters ?? 0) / 1000).toStringAsFixed(1);
      MapUtils.showSnackBar(
        context,
        '✅ تم تخزين مسار ${direction.labelAr} ($km كم) — يظهر للركاب فوراً',
      );
    } catch (e) {
      if (mounted) {
        setState(() => isSavingRoutePlan = false);
        MapUtils.showSnackBar(context, '❌ $e', isError: true);
      }
    }
  }

  Future<void> requestRoutePlanEdit(PlannedRoute route) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text('طلب تعديل مسار ${route.direction.labelAr}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'خط «${route.lineName}» مخزّن مسبقاً ويُستخدم لعدة باصات. '
                'اكتب سبب طلب التعديل ليراجعه الأدمن.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب التعديل *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final t = c.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(ctx, t);
              },
              child: const Text('إرسال الطلب'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await _routePlanService.requestEdit(
        routeId: route.id,
        reason: reason,
        requestedBy: uid,
      );
      if (mounted) {
        MapUtils.showSnackBar(
          context,
          'تم إرسال طلب التعديل للأدمن مع السبب',
        );
      }
    } catch (e) {
      if (mounted) {
        MapUtils.showSnackBar(context, '❌ فشل طلب التعديل: $e', isError: true);
      }
    }
  }

  Future<void> showRoutePlanSheet(String lineName) async {
    if (!mounted) return;
    listenLinePlannedRoutes(lineName);
    // انتظر لحظة قصيرة لتحميل أحدث حالة
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final outbound = plannedFor(RouteDirection.outbound, lineName);
        final ret = plannedFor(RouteDirection.returnTrip, lineName);
        return _RoutePlanSheet(
          lineName: lineName,
          outbound: outbound,
          returnRoute: ret,
          isRecording: isRecordingRoutePlan,
          recordingDirection: recordingDirection,
          pointCount: routePlanPointCount,
          isSaving: isSavingRoutePlan,
          onStartOutbound: () {
            Navigator.pop(ctx);
            startRoutePlanRecording(
              direction: RouteDirection.outbound,
              lineName: lineName,
            );
          },
          onStartReturn: () {
            Navigator.pop(ctx);
            startRoutePlanRecording(
              direction: RouteDirection.returnTrip,
              lineName: lineName,
            );
          },
          onSave: () {
            Navigator.pop(ctx);
            saveRoutePlanRecording(lineName: lineName);
          },
          onCancel: () {
            Navigator.pop(ctx);
            cancelRoutePlanRecording();
          },
          onRequestEdit: (r) {
            Navigator.pop(ctx);
            requestRoutePlanEdit(r);
          },
        );
      },
    );
  }

  void disposeRoutePlanRecording() {
    _plannedRoutesSub?.cancel();
    _plannedRoutesSub = null;
    _routePlanLine = null;
    _routePlanLineManager = null;
    _routePlanBuffer.clear();
    _listeningLineName = null;
  }
}

class _RoutePlanSheet extends StatelessWidget {
  final String lineName;
  final PlannedRoute? outbound;
  final PlannedRoute? returnRoute;
  final bool isRecording;
  final RouteDirection? recordingDirection;
  final int pointCount;
  final bool isSaving;
  final VoidCallback onStartOutbound;
  final VoidCallback onStartReturn;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final void Function(PlannedRoute) onRequestEdit;

  const _RoutePlanSheet({
    required this.lineName,
    required this.outbound,
    required this.returnRoute,
    required this.isRecording,
    required this.recordingDirection,
    required this.pointCount,
    required this.isSaving,
    required this.onStartOutbound,
    required this.onStartReturn,
    required this.onSave,
    required this.onCancel,
    required this.onRequestEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'مسار خطة الخط',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            lineName,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'المسار مشترك لكل باصات نفس الخط. إن كان مخزّناً مسبقاً لا حاجة لتسجيله. '
            'التعديل يتطلب موافقة الأدمن مع ذكر السبب.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Colors.grey.shade600,
            ),
          ),
          if (isRecording) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Column(
                children: [
                  Text(
                    'جاري التسجيل: ${recordingDirection?.labelAr ?? ''} · $pointCount نقطة',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isSaving ? 'جاري الحفظ…' : 'حفظ المسار'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _directionCard(
              title: 'مسار الذهاب',
              route: outbound,
              onRecord: onStartOutbound,
              onRequestEdit: onRequestEdit,
            ),
            const SizedBox(height: 10),
            _directionCard(
              title: 'مسار الإياب',
              route: returnRoute,
              onRecord: onStartReturn,
              onRequestEdit: onRequestEdit,
            ),
          ],
        ],
      ),
    );
  }

  Widget _directionCard({
    required String title,
    required PlannedRoute? route,
    required VoidCallback onRecord,
    required void Function(PlannedRoute) onRequestEdit,
  }) {
    final locked = route?.isLocked == true;
    final canReRecord = route == null || (route.canReRecord);
    final status = route == null
        ? 'غير مخزّن'
        : (route.editRequestPending
            ? 'طلب تعديل معلّق'
            : (route.canReRecord
                ? 'مسموح بإعادة التسجيل'
                : route.status.labelAr));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: locked
                      ? const Color(0xFF16A34A)
                      : Colors.orange.shade800,
                ),
              ),
            ],
          ),
          if (route != null && route.points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${route.points.length} نقطة · ${((route.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} كم'
                '${route.source == RouteSource.admin ? ' · أدمن' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          if (route?.editRequestPending == true) ...[
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'طلب تعديل بانتظار الأدمن',
                style: TextStyle(fontSize: 12, color: Color(0xFFEA580C)),
              ),
            ),
            if ((route?.editRequestReason ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'السبب: ${route!.editRequestReason}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
          const SizedBox(height: 8),
          if (canReRecord && !route!.editRequestPending)
            ElevatedButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.fiber_manual_record, size: 18),
              label: Text(
                route == null || route.points.isEmpty
                    ? 'بدء التسجيل'
                    : 'إعادة التسجيل',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
            )
          else if (route == null)
            ElevatedButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.fiber_manual_record, size: 18),
              label: const Text('بدء التسجيل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
            )
          else if (locked)
            OutlinedButton.icon(
              onPressed: () => onRequestEdit(route),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('طلب تعديل (مع السبب)'),
            )
          else if (route.editRequestPending)
            const Text(
              'انتظر قرار الأدمن',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFFEA580C)),
            ),
        ],
      ),
    );
  }
}
