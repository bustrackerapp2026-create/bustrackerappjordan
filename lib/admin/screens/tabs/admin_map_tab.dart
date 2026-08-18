import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/map/pickup_point_sheet.dart';
import '../../../../core/map/landmark_marker_images.dart';
import '../../../../core/location/location_permission_sheet.dart';
import '../../../../core/pickup/pickup_point_manager.dart';
import '../../../../core/pickup/pickup_point_dialog.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../services/location_service.dart';
import '../../../../services/map_landmark_service.dart';
import '../../../../services/map_text_label_service.dart';
import '../../../../models/map_landmark.dart';
import '../../../../models/map_text_label.dart';
import '../../../../map/widgets/search_bar_widget.dart';
import '../../../../map/utils/map_helpers.dart';
import '../../widgets/admin_draw_route_banner.dart';
import '../../widgets/admin_driver_details_sheet.dart';
import '../../widgets/admin_map_fabs.dart';
import '../../widgets/admin_routes_search_sheet.dart';
import '../../widgets/admin_landmark_form_sheet.dart';
import '../../widgets/admin_text_label_form_sheet.dart';
import '../admin_dashboard.dart';
import 'mixins/driver_manager_mixin.dart';
import 'mixins/passenger_manager_mixin.dart';
import 'mixins/route_manager_mixin.dart';
import 'mixins/pickup_point_mixin.dart';
import 'mixins/admin_draw_route_mixin.dart';
import 'mixins/admin_planned_routes_mixin.dart';
import 'mixins/admin_landmarks_mixin.dart';
import 'mixins/admin_text_labels_mixin.dart';
import '../../widgets/admin_route_direction_filter.dart';

class AdminMapTab extends StatefulWidget {
  final AdminMapFocusRequest? focusRequest;
  const AdminMapTab({super.key, this.focusRequest});
  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab>
    with
        AutomaticKeepAliveClientMixin,
        MapCoreMixin<AdminMapTab>,
        DriverManagerMixin<AdminMapTab>,
        PassengerManagerMixin<AdminMapTab>,
        RouteManagerMixin<AdminMapTab>,
        PickupPointMixin<AdminMapTab>,
        AdminDrawRouteMixin<AdminMapTab>,
        AdminPlannedRoutesMixin<AdminMapTab>,
        AdminLandmarksMixin<AdminMapTab>,
        AdminTextLabelsMixin<AdminMapTab> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final LocationService _locationService = LocationService();
  bool _isAddingPickupPoint = false;
  bool _isAddingLandmark = false;
  bool _isAddingTextLabel = false;
  bool _isLoadingLocation = false;
  StreamSubscription? _locationSubscription;
  int? _lastHandledFocusToken;

  PointAnnotation? _adminLocationAnnotation;
  Uint8List? _adminMarkerBytes;

  @override
  bool get wantKeepAlive => true;

  @override
  bool get suppressPoiTap =>
      _isAddingPickupPoint ||
      _isAddingLandmark ||
      _isAddingTextLabel ||
      isDrawingRoute;

  void _safeSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    MapUtils.showSnackBar(context, message, isError: isError);
  }

  @override
  void onStyleChanged() {
    _adminLocationAnnotation = null;
    redrawRoutes();
    unawaited(redrawPlannedRoutes());
    listenToPickupPoints();
    listenToActiveDrivers();
    listenToActivePassengers();
    unawaited(redrawLandmarks());
    unawaited(redrawTextLabels());
  }

  @override
  void didUpdateWidget(covariant AdminMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleFocusRequest();
  }

  @override
  void onMapCreated(MapboxMap map) {
    super.onMapCreated(map);
    unawaited(MapHelpers.createUserMarkerBytes().then((b) {
      _adminMarkerBytes = b;
    }));
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      listenToActiveDrivers();
      listenToActivePassengers();
      listenToRoutes();
      listenToPlannedRoutes();
      listenToLandmarks();
      listenToTextLabels();
      listenToPickupPoints();
      applyLabelLayersFilter();
      _scheduleFocusRequest();
    });
  }

  void _scheduleFocusRequest() {
    final focus = widget.focusRequest;
    if (focus == null || _lastHandledFocusToken == focus.token) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyFocusRequest(focus);
    });
  }

  void _applyFocusRequest(AdminMapFocusRequest focus) {
    if (_lastHandledFocusToken == focus.token || mapboxMap == null) return;
    _lastHandledFocusToken = focus.token;
    mapboxMap?.setCamera(CameraOptions(
      center: Point(coordinates: Position(focus.longitude, focus.latitude)),
      zoom: 16.5,
      pitch: 0,
      bearing: 0,
    ));
    _safeSnack('📍 تم التوجيه إلى: ${focus.pointName}');
  }

  @override
  void dispose() {
    disposeMapDebug();
    _locationSubscription?.cancel();
    _adminLocationAnnotation = null;
    disposeAdminDrawRoute();
    disposePlannedRoutes();
    disposeLandmarks();
    disposeTextLabels();
    disposePickupPoints();
    disposeRoutes();
    disposePassengers();
    disposeDrivers();
    super.dispose();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted || isDrawingRoute) return;

    final driverId = findDriverIdByAnnotation(annotation);
    if (driverId != null) {
      final data = getDriverData(driverId);
      if (data != null) {
        unawaited(AdminDriverDetailsSheet.show(context, data));
      } else {
        _safeSnack('لا تتوفر بيانات هذا السائق حالياً', isError: true);
      }
      return;
    }

    final textLabelId = findTextLabelIdByAnnotation(annotation);
    if (textLabelId != null) {
      final label = getTextLabelById(textLabelId);
      if (label != null) {
        _showTextLabelInfo(label);
      }
      return;
    }

    final landmarkId = findLandmarkIdByAnnotation(annotation);
    if (landmarkId != null) {
      final m = getLandmarkById(landmarkId);
      if (m != null) {
        _showLandmarkInfo(m);
      }
      return;
    }

    final pickupId = _findId(pickupAnnotations, annotation);
    if (pickupId != null) _showPickupActionsSheet(pickupId);
  }

  void _showTextLabelInfo(MapTextLabel label) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.text_fields_rounded, size: 36),
              const SizedBox(height: 12),
              Text(
                label.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: label.fontSize.clamp(14, 22),
                  fontWeight: FontWeight.w800,
                  color: Color(label.colorArgb),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'حجم ${label.fontSize.round()} · اتجاه ${label.rotation.round()}°',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_editTextLabel(label));
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_deleteTextLabel(label));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editTextLabel(MapTextLabel label) async {
    final result = await AdminTextLabelFormSheet.show(
      context,
      title: 'تعديل نص على الخريطة',
      initial: label,
      latitude: label.latitude,
      longitude: label.longitude,
    );
    if (result == null || !mounted) return;
    try {
      await MapTextLabelService().updateLabel(
        id: label.id,
        text: result.text,
        fontSize: result.fontSize,
        rotation: result.rotation,
        colorArgb: result.colorArgb,
      );
      if (!mounted) return;
      _safeSnack('✅ تم تحديث النص');
    } catch (e) {
      if (!mounted) return;
      _safeSnack('فشل التحديث: $e', isError: true);
    }
  }

  Future<void> _deleteTextLabel(MapTextLabel label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف النص؟'),
        content: Text('سيتم حذف «${label.text}» نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await MapTextLabelService().deleteLabel(label.id);
      if (!mounted) return;
      _safeSnack('🗑️ تم حذف النص');
    } catch (e) {
      if (!mounted) return;
      _safeSnack('فشل الحذف: $e', isError: true);
    }
  }

  void _showLandmarkInfo(MapLandmark m) {
    if (!mounted) return;
    final color = LandmarkMarkerImages.colorFor(m.type);
    final icon = LandmarkMarkerImages.iconDataFor(m.type);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                m.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                m.type.labelAr,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (m.notes != null && m.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  m.notes!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_editLandmark(m));
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_deleteLandmark(m));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editLandmark(MapLandmark m) async {
    final result = await AdminLandmarkFormSheet.show(
      context,
      title: 'تعديل معلم',
      initial: m,
      latitude: m.latitude,
      longitude: m.longitude,
    );
    if (result == null || !mounted) return;
    try {
      await MapLandmarkService().updateLandmark(
        id: m.id,
        name: result.name,
        type: result.type,
        notes: result.notes,
      );
      if (!mounted) return;
      _safeSnack('✅ تم تحديث المعلم');
    } catch (e) {
      if (!mounted) return;
      _safeSnack('فشل التحديث: $e', isError: true);
    }
  }

  Future<void> _deleteLandmark(MapLandmark m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المعلم؟'),
        content: Text('سيتم حذف «${m.name}» نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await MapLandmarkService().deleteLandmark(m.id);
      if (!mounted) return;
      _safeSnack('🗑️ تم حذف المعلم');
    } catch (e) {
      if (!mounted) return;
      _safeSnack('فشل الحذف: $e', isError: true);
    }
  }

  String? _findId(Map<String, PointAnnotation> map, PointAnnotation a) {
    for (final e in map.entries) {
      if (e.value.id == a.id) return e.key;
    }
    return null;
  }

  void _startAddPickupPoint() {
    if (isDrawingRoute) {
      unawaited(cancelDrawingRoute());
    }
    if (_isAddingLandmark) setState(() => _isAddingLandmark = false);
    if (_isAddingTextLabel) setState(() => _isAddingTextLabel = false);
    setState(() => _isAddingPickupPoint = true);
    _safeSnack('📍 اضغط على الخريطة لتحديد موقع النقطة');
  }

  void _cancelAddPickupPoint() {
    setState(() => _isAddingPickupPoint = false);
    _safeSnack('❌ تم إلغاء إضافة النقطة', isError: true);
  }

  void _toggleAddLandmark() {
    if (_isAddingLandmark) {
      setState(() => _isAddingLandmark = false);
      _safeSnack('تم إلغاء إضافة المعلم');
      return;
    }
    if (isDrawingRoute) unawaited(cancelDrawingRoute());
    if (_isAddingPickupPoint) setState(() => _isAddingPickupPoint = false);
    if (_isAddingTextLabel) setState(() => _isAddingTextLabel = false);
    setState(() => _isAddingLandmark = true);
    _safeSnack('📍 اضغط على الخريطة لتحديد موقع المعلم');
  }

  void _toggleAddTextLabel() {
    if (_isAddingTextLabel) {
      setState(() => _isAddingTextLabel = false);
      _safeSnack('تم إلغاء إضافة النص');
      return;
    }
    if (isDrawingRoute) unawaited(cancelDrawingRoute());
    if (_isAddingPickupPoint) setState(() => _isAddingPickupPoint = false);
    if (_isAddingLandmark) setState(() => _isAddingLandmark = false);
    setState(() => _isAddingTextLabel = true);
    _safeSnack('✍️ اضغط على الخريطة لوضع النص (اسم شارع...)');
  }

  Future<void> _handleLandmarkMapTap(Point point) async {
    if (!_isAddingLandmark || !mounted) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) {
      _safeSnack('⚠️ يرجى تسجيل الدخول أولاً', isError: true);
      setState(() => _isAddingLandmark = false);
      return;
    }
    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();
    final result = await AdminLandmarkFormSheet.show(
      context,
      title: 'إضافة معلم',
      latitude: lat,
      longitude: lng,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _isAddingLandmark = false);
      return;
    }
    try {
      await MapLandmarkService().createLandmark(
        name: result.name,
        type: result.type,
        latitude: lat,
        longitude: lng,
        createdBy: userId,
        notes: result.notes,
      );
      if (!mounted) return;
      _safeSnack('✅ تم إضافة المعلم');
    } catch (e) {
      if (!mounted) return;
      _safeSnack('فشل الإضافة: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingLandmark = false);
    }
  }

  Future<void> _handleTextLabelMapTap(Point point) async {
    if (!_isAddingTextLabel || !mounted) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) {
      _safeSnack('⚠️ يرجى تسجيل الدخول أولاً', isError: true);
      setState(() => _isAddingTextLabel = false);
      return;
    }
    final lat = point.coordinates.lat.toDouble();
    final lng = point.coordinates.lng.toDouble();
    final result = await AdminTextLabelFormSheet.show(
      context,
      title: 'إضافة نص على الخريطة',
      latitude: lat,
      longitude: lng,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _isAddingTextLabel = false);
      return;
    }
    try {
      await MapTextLabelService().createLabel(
        text: result.text,
        latitude: lat,
        longitude: lng,
        createdBy: userId,
        fontSize: result.fontSize,
        rotation: result.rotation,
        colorArgb: result.colorArgb,
      );
      if (!mounted) return;
      _safeSnack('✅ تم إضافة النص');
    } catch (e) {
      if (!mounted) return;
      _safeSnack('فشل الإضافة: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingTextLabel = false);
    }
  }

  void _toggleDrawRoute() {
    if (isDrawingRoute) {
      unawaited(cancelDrawingRoute());
    } else {
      if (_isAddingPickupPoint) setState(() => _isAddingPickupPoint = false);
      if (_isAddingLandmark) setState(() => _isAddingLandmark = false);
      if (_isAddingTextLabel) setState(() => _isAddingTextLabel = false);
      startDrawingRoute();
    }
  }

  Future<void> _toggleRoutesVisibility() async {
    await togglePlannedRoutesVisibility();
    if (!mounted) return;
    _safeSnack(
      showPlannedRoutes
          ? '🚌 تم إظهار المسارات (${plannedRouteFilter.labelAr})'
          : '🙈 تم إخفاء المسارات',
    );
  }

  Future<void> _onRouteFilterChanged(AdminRouteDirectionFilter filter) async {
    await setPlannedRouteFilter(filter);
    if (!mounted) return;
    _safeSnack('عرض: ${filter.shortHint}');
  }

  Future<void> _goToMyLocation() async {
    if (mapboxMap == null || !mounted) return;
    setState(() => _isLoadingLocation = true);

    try {
      final granted = await LocationPermissionSheet.ensurePermission(context);
      if (!mounted) return;
      if (!granted) {
        _safeSnack('⚠️ لم يتم منح صلاحية الموقع', isError: true);
        return;
      }

      var shown = false;

      final position = await _locationService.locateProgressive(
        quickTimeout: const Duration(seconds: 2),
        preciseTimeout: const Duration(seconds: 6),
        onProgress: (pos, stage) {
          if (!mounted) return;
          shown = true;
          unawaited(_showAdminLocation(
            pos.latitude,
            pos.longitude,
            moveCamera: true,
          ));
        },
      );

      if (!mounted) return;

      if (position == null && !shown) {
        _safeSnack('⚠️ تعذر الحصول على الموقع. تأكد من تفعيل GPS',
            isError: true);
        return;
      }

      if (position != null) {
        await _showAdminLocation(
          position.latitude,
          position.longitude,
          moveCamera: true,
        );
      }

      if (!mounted) return;
      _safeSnack('📍 تم تحديد موقعك');
    } catch (e) {
      if (mounted) {
        _safeSnack('❌ تعذر تحديد الموقع', isError: true);
      }
      MapUtils.log('admin location: $e', tag: 'AdminMap');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _showAdminLocation(
    double lat,
    double lng, {
    required bool moveCamera,
  }) async {
    if (mapboxMap == null) return;

    if (moveCamera) {
      try {
        await mapboxMap!.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: 16.0,
            pitch: 0,
            bearing: 0,
          ),
        );
      } catch (_) {
        await flyToFlat(latitude: lat, longitude: lng, zoom: 16);
      }
    }

    final manager = pointAnnotationManager;
    if (manager == null) return;

    final point = Point(coordinates: Position(lng, lat));

    if (_adminLocationAnnotation != null) {
      _adminLocationAnnotation!.geometry = point;
      try {
        await manager.update(_adminLocationAnnotation!);
      } catch (_) {
        _adminLocationAnnotation = null;
      }
      if (_adminLocationAnnotation != null) return;
    }

    _adminMarkerBytes ??= await MapHelpers.createUserMarkerBytes();
    if (!mounted) return;

    try {
      _adminLocationAnnotation = await manager.create(
        PointAnnotationOptions(
          geometry: point,
          image: _adminMarkerBytes!,
          iconSize: 1.15,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (e) {
      MapUtils.log('admin marker: $e', tag: 'AdminMap');
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;

    final match = routes.where(
      (r) =>
          r.name.contains(query.trim()) ||
          r.startCity.contains(query.trim()) ||
          r.endCity.contains(query.trim()),
    );
    if (match.isNotEmpty) {
      onRouteFilterChanged(match.first.name);
      _safeSnack('🚌 تم اختيار المسار: ${match.first.name}');
      return;
    }

    final result = await _locationService.searchPlace(query);
    if (!mounted) return;

    if (result == null) {
      _safeSnack('⚠️ لم يتم العثور على المكان', isError: true);
      return;
    }

    await flyToFlat(
      latitude: result.latitude,
      longitude: result.longitude,
      zoom: 15,
    );
    if (!mounted) return;
    _safeSnack('🔎 تم الانتقال إلى ${result.name}');
  }

  Future<void> _handleMapTap(Point point) async {
    if (!_isAddingPickupPoint || !mounted) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    final userData = auth.userData;

    if (userId == null || userData == null) {
      _safeSnack('⚠️ يرجى تسجيل الدخول أولاً', isError: true);
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    final result = await showPickupPointPickerDialog(context: context);
    if (!mounted) return;

    if (result == null || result.name.trim().isEmpty) {
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    try {
      await _pickupManager.addPickupPoint(
        name: result.name.trim(),
        latitude: point.coordinates.lat.toDouble(),
        longitude: point.coordinates.lng.toDouble(),
        userId: userId,
        userType: userData.userType,
        pointType: result.pointType,
      );
      if (!mounted) return;
      _safeSnack('✅ تم إضافة النقطة');
    } catch (_) {
      _safeSnack('❌ فشل إضافة النقطة', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingPickupPoint = false);
    }
  }

  Future<void> _showPickupActionsSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted || point == null) return;

    final adderName = await PickupPointSheet.loadAdderName(point.addedBy);
    if (!mounted) return;

    final action = await PickupPointSheet.show(
      context: context,
      point: point,
      mode: PickupSheetMode.admin,
      adderName: adderName,
    );

    if (!mounted || action == null || action == PickupSheetAction.close) return;

    if (action == PickupSheetAction.edit) {
      if (!mounted) return;
      final updated = await showPickupPointPickerDialog(
        context: context,
        initialName: point.name,
        initialPointType: point.pointType,
      );
      if (updated == null || !mounted) return;
      await _pickupManager.updatePickupPoint(
        pointId: pickupId,
        data: {'name': updated.name.trim(), 'pointType': updated.pointType},
      );
      if (!mounted) return;
      _safeSnack('✅ تم تعديل النقطة');
    } else if (action == PickupSheetAction.delete) {
      await _pickupManager.deletePickupPoint(pointId: pickupId);
      if (!mounted) return;
      _safeSnack('🗑️ تم حذف النقطة');
    } else if (action == PickupSheetAction.approve) {
      await _pickupManager.updatePickupPoint(
        pointId: pickupId,
        data: {'status': 'approved'},
      );
      if (!mounted) return;
      _safeSnack('✅ تم اعتماد النقطة');
    } else if (action == PickupSheetAction.reject) {
      await _pickupManager.updatePickupPoint(
        pointId: pickupId,
        data: {'status': 'rejected'},
      );
      if (!mounted) return;
      _safeSnack('🚫 تم رفض النقطة');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        RepaintBoundary(
          child: MapWidget(
            key: const ValueKey('admin_map_widget'),
            textureView: true,
            onMapCreated: onMapCreated,
            onCameraChangeListener: onCameraChangedForDebug,
            // ignore: deprecated_member_use
            onTapListener: (event) {
              if (isDrawingRoute) {
                onDrawRouteMapTap(event.point);
              } else if (_isAddingTextLabel) {
                _handleTextLabelMapTap(event.point);
              } else if (_isAddingLandmark) {
                _handleLandmarkMapTap(event.point);
              } else if (_isAddingPickupPoint) {
                _handleMapTap(event.point);
              } else {
                handleMapBackgroundTap(event);
              }
            },
            styleUri: MapCoreMixin.initialMapStyle,
          ),
        ),
        if (!isMapReady) const Center(child: CircularProgressIndicator()),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: ValueListenableBuilder<int>(
            valueListenable: routesUiTick,
            builder: (_, __, ___) {
              return SearchBarWidget(
                selectedRoute: selectedRouteName,
                routes: routeDropdownItems,
                onRouteChanged: onRouteFilterChanged,
                onSearchSubmitted: _searchPlace,
              );
            },
          ),
        ),
        if (isDrawingRoute)
          Positioned(
            top: 72,
            left: 16,
            right: 16,
            child: AdminDrawRouteBanner(
              drawPointCount: drawPointCount,
              isSnappingSegment: isSnappingSegment,
              onSave: drawPointCount >= 2 && !isSnappingSegment
                  ? finishAndSaveDrawnRoute
                  : null,
              onUndo: isSnappingSegment ? null : undoLastDrawPoint,
              onCancel: cancelDrawingRoute,
            ),
          ),
        Positioned.fill(
          child: ValueListenableBuilder<int>(
            valueListenable: plannedRoutesUiTick,
            builder: (_, __, ___) {
              return AdminMapFabs(
                showPassengers: showPassengers,
                showRoutes: showPlannedRoutes,
                isAddingPickupPoint: _isAddingPickupPoint,
                isDrawingRoute: isDrawingRoute,
                isAddingLandmark: _isAddingLandmark,
                isAddingTextLabel: _isAddingTextLabel,
                isLoadingLocation: _isLoadingLocation,
                routeFilter: plannedRouteFilter,
                outboundCount: outboundRoutesCount,
                returnCount: returnRoutesCount,
                onTogglePassengers: togglePassengersVisibility,
                onToggleRoutes: () => unawaited(_toggleRoutesVisibility()),
                onRouteFilterChanged: (f) =>
                    unawaited(_onRouteFilterChanged(f)),
                onTogglePickup: _isAddingPickupPoint
                    ? _cancelAddPickupPoint
                    : _startAddPickupPoint,
                onToggleDrawRoute: _toggleDrawRoute,
                onMyLocation: _goToMyLocation,
                onMapLayers: () => showMapSettingsSheet(context),
                onSearchRoutes: () {
                  AdminRoutesSearchSheet.show(
                    context,
                    onFocusRoute: (route) {
                      if (route.points.isEmpty) return;
                      final p = route.points[route.points.length ~/ 2];
                      unawaited(flyToFlat(
                        latitude: p.latitude,
                        longitude: p.longitude,
                        zoom: 13,
                      ));
                    },
                  );
                },
                onToggleAddLandmark: _toggleAddLandmark,
                onToggleAddTextLabel: _toggleAddTextLabel,
              );
            },
          ),
        ),
      ],
    );
  }
}
