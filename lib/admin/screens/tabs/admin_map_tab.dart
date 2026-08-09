import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/map/map_utils.dart';
import '../../../../core/map/map_core.dart';
import '../../../../core/pickup/pickup_point_manager.dart';
import '../../../../core/pickup/pickup_point_dialog.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../services/location_service.dart';
import '../../../../map/widgets/search_bar_widget.dart';
import '../admin_dashboard.dart';
import 'mixins/driver_manager_mixin.dart';
import 'mixins/passenger_manager_mixin.dart';
import 'mixins/route_manager_mixin.dart';
import 'mixins/pickup_point_mixin.dart';

class AdminMapTab extends StatefulWidget {
  final AdminMapFocusRequest? focusRequest;

  const AdminMapTab({super.key, this.focusRequest});

  @override
  State<AdminMapTab> createState() => _AdminMapTabState();
}

class _AdminMapTabState extends State<AdminMapTab>
    with
        MapCoreMixin<AdminMapTab>,
        DriverManagerMixin<AdminMapTab>,
        PassengerManagerMixin<AdminMapTab>,
        RouteManagerMixin<AdminMapTab>,
        PickupPointMixin<AdminMapTab> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final LocationService _locationService = LocationService();
  bool _isAddingPickupPoint = false;
  bool _isLoadingLocation = false;
  StreamSubscription<Position>? _locationSubscription;
  int? _lastHandledFocusToken;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant AdminMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleFocusRequest();
  }

  @override
  void onMapCreated(MapboxMap map) {
    super.onMapCreated(map);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      listenToActiveDrivers();
      listenToActivePassengers();
      listenToRoutes();
      listenToPickupPoints();
      _scheduleFocusRequest();
      MapUtils.log('✅ تم تهيئة جميع ميزات خريطة الأدمن', tag: 'AdminMap');
    });
  }

  /// لا نستدعي SnackBar أثناء build — نؤجل لما بعد الإطار الحالي
  void _scheduleFocusRequest() {
    final focus = widget.focusRequest;
    if (focus == null) return;
    if (_lastHandledFocusToken == focus.token) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyFocusRequest(focus);
    });
  }

  void _applyFocusRequest(AdminMapFocusRequest focus) {
    if (_lastHandledFocusToken == focus.token) return;
    if (mapboxMap == null) return;

    _lastHandledFocusToken = focus.token;

    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(focus.longitude, focus.latitude),
        ),
        zoom: 16.5,
        pitch: 45.0,
      ),
    );

    if (!mounted) return;
    MapUtils.showSnackBar(
      context,
      '📍 تم التوجيه إلى: ${focus.pointName}',
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    disposePickupPoints();
    disposeRoutes();
    disposePassengers();
    disposeDrivers();
    super.dispose();
  }

  @override
  void handleAnnotationTap(PointAnnotation annotation) {
    if (!mounted) return;

    final selectedDriverId = _findDriverIdByAnnotation(annotation);
    if (selectedDriverId != null) {
      _showDriverDetailsBottomSheet(selectedDriverId);
      return;
    }

    final selectedPickupId = _findPickupIdByAnnotation(annotation);
    if (selectedPickupId != null) {
      _showPickupActionsSheet(selectedPickupId);
      return;
    }

    MapUtils.log(
      '⚠️ تم النقر على علامة غير معروفة: ${annotation.id}',
      tag: 'AdminMap',
    );
  }

  String? _findDriverIdByAnnotation(PointAnnotation annotation) {
    for (final entry in driverAnnotations.entries) {
      if (entry.value.id == annotation.id) {
        return entry.key;
      }
    }
    return null;
  }

  String? _findPickupIdByAnnotation(PointAnnotation annotation) {
    for (final entry in pickupAnnotations.entries) {
      if (entry.value.id == annotation.id) {
        return entry.key;
      }
    }
    return null;
  }

  void _showDriverDetailsBottomSheet(String driverId) {
    if (!mounted) return;
    MapUtils.showSnackBar(
      context,
      '🔄 جاري تحميل بيانات السائق (ID: $driverId)...',
      duration: const Duration(seconds: 2),
    );
  }

  String _userTypeLabel(String type) {
    switch (type) {
      case 'driver':
        return 'سائق';
      case 'passenger':
        return 'راكب';
      case 'admin':
        return 'أدمن';
      case 'service':
        return 'سرفيس';
      case 'bus_company':
        return 'شركة باصات';
      default:
        return type;
    }
  }

  Future<String> _loadAdderName(String userId) async {
    if (userId.isEmpty) return 'غير معروف';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = doc.data()?['fullName'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
      return 'بدون اسم';
    } catch (_) {
      return 'تعذر جلب الاسم';
    }
  }

  void _startAddPickupPoint() {
    if (_isAddingPickupPoint) return;
    setState(() => _isAddingPickupPoint = true);
    MapUtils.showSnackBar(
      context,
      '📍 اضغط على الخريطة لتحديد موقع النقطة',
      duration: const Duration(seconds: 3),
    );
  }

  void _cancelAddPickupPoint() {
    if (!_isAddingPickupPoint) return;
    setState(() => _isAddingPickupPoint = false);
    MapUtils.showSnackBar(
      context,
      '❌ تم إلغاء إضافة النقطة',
      isError: true,
      duration: const Duration(seconds: 1),
    );
  }

  Future<void> _goToMyLocation() async {
    if (mapboxMap == null) return;
    if (!mounted) return;

    setState(() => _isLoadingLocation = true);

    try {
      final hasPermission = await _locationService.checkAndRequestPermission();
      if (!mounted) return;
      if (!hasPermission) {
        MapUtils.showSnackBar(context, '⚠️ يرجى تفعيل الموقع أولاً',
            isError: true);
        return;
      }

      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        MapUtils.showSnackBar(context, '⚠️ تعذر الحصول على الموقع الحالي',
            isError: true);
        return;
      }

      mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
              coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
          pitch: 45.0,
        ),
      );
      if (mounted) {
        MapUtils.showSnackBar(context, '📍 تم تحديد موقعك الحالي');
      }
    } catch (e) {
      if (!mounted) return;
      MapUtils.log('❌ خطأ تحديد الموقع: $e', tag: 'AdminMap');
      MapUtils.showSnackBar(context, '❌ تعذر تحديد موقعك', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    if (!mounted) return;

    final result = await _locationService.searchPlace(query);
    if (!mounted) return;
    if (result == null) {
      MapUtils.showSnackBar(context, '⚠️ لم يتم العثور على المكان',
          isError: true);
      return;
    }

    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(result.longitude, result.latitude)),
        zoom: 15.0,
        pitch: 45.0,
      ),
    );
    if (mounted) {
      MapUtils.showSnackBar(context, '🔎 تم الانتقال إلى ${result.name}');
    }
  }

  void _handleMapTap(Point point) async {
    if (!_isAddingPickupPoint) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    final userData = authProvider.userData;

    if (userId == null || userData == null) {
      MapUtils.showSnackBar(
        context,
        '⚠️ يرجى تسجيل الدخول أولاً',
        isError: true,
      );
      if (mounted) setState(() => _isAddingPickupPoint = false);
      return;
    }

    final double lat = point.coordinates.lat.toDouble();
    final double lng = point.coordinates.lng.toDouble();

    final result = await showPickupPointPickerDialog(context: context);
    if (!mounted) return;

    if (result == null || result.name.trim().isEmpty) {
      setState(() => _isAddingPickupPoint = false);
      return;
    }

    try {
      await _pickupManager.addPickupPoint(
        name: result.name.trim(),
        latitude: lat,
        longitude: lng,
        userId: userId,
        userType: userData.userType,
        pointType: result.pointType,
      );

      if (!mounted) return;

      MapUtils.showSnackBar(
        context,
        '✅ تم إضافة النقطة "${result.name.trim()}" وستظهر فوراً للسائق والراكب',
      );
    } catch (e) {
      if (!mounted) return;
      MapUtils.log('❌ فشل إضافة النقطة: $e', tag: 'AdminMap');
      MapUtils.showSnackBar(
        context,
        '❌ حدث خطأ أثناء إضافة النقطة. يرجى المحاولة لاحقاً.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isAddingPickupPoint = false);
    }
  }

  Future<void> _showPickupActionsSheet(String pickupId) async {
    if (!mounted) return;

    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted) return;
    if (point == null) return;

    final adderNameFuture = _loadAdderName(point.addedBy);

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return FutureBuilder<String>(
          future: adderNameFuture,
          builder: (context, adderSnap) {
            final adderName = adderSnap.data ?? 'جاري التحميل...';
            final count = point.confirmationCount;
            final confirmLabel = count == 0
                ? 'لم يؤكدها أحد بعد'
                : count == 1
                    ? 'أكدها شخص واحد'
                    : 'أكدها $count أشخاص';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      point.pointType == 'passenger'
                          ? '🚶 تجمع ركاب'
                          : '🚌 تجمع باصات',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user,
                              color: Colors.green.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              confirmLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: const Text('أضافها'),
                      subtitle: Text(
                        '$adderName · ${_userTypeLabel(point.addedByUserType)}',
                      ),
                    ),
                    const Divider(height: 20),
                    ListTile(
                      leading: const Icon(Icons.edit_rounded,
                          color: AppTheme.primaryColor),
                      title: const Text('تعديل النقطة'),
                      onTap: () => Navigator.pop(sheetContext, 'edit'),
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.delete_rounded, color: Colors.red),
                      title: const Text('حذف النقطة'),
                      onTap: () => Navigator.pop(sheetContext, 'delete'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (action == 'edit') {
      final updated = await showPickupPointPickerDialog(
        context: context,
        initialName: point.name,
        initialPointType: point.pointType,
      );
      if (!mounted) return;
      if (updated == null || updated.name.trim().isEmpty) return;

      try {
        await _pickupManager.updatePickupPoint(
          pointId: pickupId,
          data: {
            'name': updated.name.trim(),
            'pointType': updated.pointType,
          },
        );
        if (!mounted) return;
        MapUtils.showSnackBar(context, '✅ تم تعديل النقطة');
      } catch (e) {
        if (!mounted) return;
        MapUtils.showSnackBar(context, '❌ فشل تعديل النقطة', isError: true);
      }
      return;
    }

    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف النقطة؟'),
          content: Text('هل تريد حذف ${point.name}؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (confirm != true) return;

      try {
        await _pickupManager.deletePickupPoint(pointId: pickupId);
        if (!mounted) return;
        MapUtils.showSnackBar(context, '🗑️ تم حذف النقطة');
      } catch (e) {
        if (!mounted) return;
        MapUtils.showSnackBar(context, '❌ فشل حذف النقطة', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('admin_map_widget'),
          onMapCreated: onMapCreated,
          // ignore: deprecated_member_use
          onTapListener: (event) {
            if (!_isAddingPickupPoint) return;
            _handleMapTap(event.point);
          },
          styleUri: currentMapStyle,
        ),
        if (!isMapReady) const Center(child: CircularProgressIndicator()),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SearchBarWidget(
            selectedRoute: 'الكل',
            routes: const ['الكل'],
            onRouteChanged: (_) {},
            onSearchSubmitted: (query) async => _searchPlace(query),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'admin_passengers_toggle',
            onPressed: togglePassengersVisibility,
            backgroundColor:
                showPassengers ? Colors.blue.shade700 : Colors.grey,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: Icon(
              showPassengers ? Icons.person : Icons.person_off,
              size: 26,
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_add_pickup',
            onPressed: _isAddingPickupPoint
                ? _cancelAddPickupPoint
                : _startAddPickupPoint,
            backgroundColor: _isAddingPickupPoint ? Colors.red : Colors.orange,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: Icon(
              _isAddingPickupPoint ? Icons.close : Icons.add_location,
              size: 26,
            ),
          ),
        ),
        Positioned(
          bottom: 180,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_location_fab',
            onPressed: _goToMyLocation,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryColor,
            elevation: 4,
            shape: const CircleBorder(),
            child: _isLoadingLocation
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.my_location_rounded, size: 26),
          ),
        ),
        Positioned(
          bottom: 30,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'admin_map_layers_fab',
            onPressed: () => showMapSettingsSheet(context),
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
}
