import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../models/pickup_point_model.dart';
import '../map/map_core.dart';
import '../map/map_utils.dart';
import '../map/pickup_point_sheet.dart';
import '../theme/app_theme.dart';
import 'pickup_marker_helper.dart';
import 'pickup_point_dialog.dart';
import 'pickup_point_manager.dart';

/// مكسين مشترك لعرض نقاط التجمع على خرائط السائق والراكب.
///
/// يعرض **كل النقاط المعتمدة** بغض النظر عن تاريخ إنشاء الحساب،
/// ويدعم الحقول القديمة (isApproved) والجديدة (status).
mixin PickupPointMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, String> _pickupAnnotationToPointId = {};
  final Map<String, Uint8List> _markerImageCache = {};
  final Map<String, String> _markerVisualKey = {};
  StreamSubscription<QuerySnapshot>? _pickupPointsSubscription;
  bool _isAddingPickupPoint = false;
  bool _isSyncingMarkers = false;
  QuerySnapshot? _pendingSnapshot;
  bool _resyncScheduled = false;

  bool get isAddingPickupPoint => _isAddingPickupPoint;

  Map<String, PointAnnotation> get pickupAnnotations => _pickupAnnotations;

  void toggleAddingPickupPoint() {
    _isAddingPickupPoint = !_isAddingPickupPoint;
  }

  /// هل المستند معتمد للعرض على الخريطة؟
  bool _isApprovedDoc(Map<String, dynamic> data) {
    final status = data['status']?.toString();
    final isApprovedFlag = data['isApproved'] == true;

    // مرفوض صراحةً
    if (status == 'rejected') return false;

    // معتمد بالحقل الجديد أو القديم
    if (status == 'approved' || isApprovedFlag) return true;

    // معلق فقط
    if (status == 'pending') return false;

    // بيانات قديمة بلا status: اعتبرها معتمدة إن وُجدت إحداثيات صالحة
    // (بعض النقاط القديمة لم تُكتب لها status)
    if (status == null || status.isEmpty) {
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
        // إن وُجد isApproved=false صراحةً لا نعرض
        if (data.containsKey('isApproved') && data['isApproved'] != true) {
          return false;
        }
        return true;
      }
    }

    return false;
  }

  void listenToPickupPoints() {
    _pickupPointsSubscription?.cancel();

    // نجلب المجموعة كاملة ونصفّي محلياً لدعم النقاط القديمة
    // (status / isApproved) دون الحاجة لفهرس مركّب.
    _pickupPointsSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .snapshots()
        .listen(
      (snapshot) {
        MapUtils.log(
          '📦 [Pickup] مستندات: ${snapshot.docs.length} '
          '(تغيّرات: ${snapshot.docChanges.length})',
          tag: 'PickupMixin',
        );
        _pendingSnapshot = snapshot;
        _syncPickupMarkers();
      },
      onError: (error) {
        MapUtils.log(
          '⚠️ خطأ في جلب نقاط التجمع: $error',
          tag: 'PickupMixin',
        );
      },
    );
  }

  void _scheduleResync() {
    if (_resyncScheduled) return;
    _resyncScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      _resyncScheduled = false;
      if (mounted) _syncPickupMarkers();
    });
  }

  Future<void> _syncPickupMarkers() async {
    if (!mounted || _isSyncingMarkers) return;

    final snapshot = _pendingSnapshot;
    if (snapshot == null) return;

    if (pointAnnotationManager == null) {
      // الخريطة ليست جاهزة بعد — أعد المحاولة قريباً
      _scheduleResync();
      return;
    }

    _isSyncingMarkers = true;
    try {
      final approvedPoints = <PickupPointModel>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (!_isApprovedDoc(data)) continue;

          final point = PickupPointModel.fromFirestore(doc);
          if (point.latitude == 0.0 && point.longitude == 0.0) continue;
          approvedPoints.add(point);
        } catch (e) {
          MapUtils.log(
            '⚠️ تخطي نقطة ${doc.id}: $e',
            tag: 'PickupMixin',
          );
        }
      }

      final newIds = approvedPoints.map((p) => p.id).toSet();
      final currentIds = _pickupAnnotations.keys.toSet();
      final toRemove = currentIds.difference(newIds);

      for (final id in toRemove) {
        if (!mounted) return;
        await _removePickupMarker(id);
      }

      for (final point in approvedPoints) {
        if (!mounted) return;
        await _upsertPickupMarker(point);
      }

      MapUtils.log(
        '✅ [Pickup] معروض ${_pickupAnnotations.length} / '
        'معتمدة ${approvedPoints.length} من أصل ${snapshot.docs.length}',
        tag: 'PickupMixin',
      );
    } finally {
      _isSyncingMarkers = false;

      // إن وصل snapshot أحدث أثناء المزامنة
      if (_pendingSnapshot != snapshot && mounted) {
        _scheduleResync();
      }
    }
  }

  Future<void> _removePickupMarker(String pointId) async {
    final existing = _pickupAnnotations.remove(pointId);
    if (existing != null) {
      try {
        await pointAnnotationManager?.delete(existing);
      } catch (_) {}
      _pickupAnnotationToPointId.remove(existing.id);
    }
    _markerVisualKey.remove(pointId);
  }

  Future<void> _upsertPickupMarker(PickupPointModel point) async {
    if (pointAnnotationManager == null || !mounted) return;

    final visualKey =
        '${point.pointType}_${point.name.hashCode}_${point.confirmationCount}';
    final existing = _pickupAnnotations[point.id];

    if (existing != null && _markerVisualKey[point.id] == visualKey) {
      existing.geometry = Point(
        coordinates: Position(point.longitude, point.latitude),
      );
      try {
        await pointAnnotationManager?.update(existing);
      } catch (_) {}
      return;
    }

    if (existing != null) {
      _pickupAnnotations.remove(point.id);
      try {
        await pointAnnotationManager?.delete(existing);
      } catch (_) {}
      _pickupAnnotationToPointId.remove(existing.id);
    }

    final bytes = await _markerBytesFor(point, visualKey);
    if (bytes == null || !mounted) return;

    final options = PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(point.longitude, point.latitude),
      ),
      image: bytes,
      iconSize: 1.05,
      iconAnchor: IconAnchor.BOTTOM,
    );

    final annotation = await pointAnnotationManager?.create(options);
    if (annotation != null) {
      _pickupAnnotations[point.id] = annotation;
      _pickupAnnotationToPointId[annotation.id] = point.id;
      _markerVisualKey[point.id] = visualKey;
    }
  }

  Future<Uint8List?> _markerBytesFor(
    PickupPointModel point,
    String visualKey,
  ) async {
    final cacheKey = '${point.id}_$visualKey';
    final cached = _markerImageCache[cacheKey];
    if (cached != null) return cached;

    final bytes = await PickupMarkerHelper.createMarkerBytes(
      name: point.name,
      pointType: point.pointType,
      confirmationCount: point.confirmationCount,
    );
    if (bytes != null) {
      if (_markerImageCache.length > 80) {
        _markerImageCache.clear();
      }
      _markerImageCache[cacheKey] = bytes;
    }
    return bytes;
  }

  String? findPickupIdByAnnotation(PointAnnotation annotation) {
    return _pickupAnnotationToPointId[annotation.id];
  }

  Future<void> showPickupPointSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted || point == null) return;

    final user = context.read<AuthProvider>().userId;
    final adderName = await PickupPointSheet.loadAdderName(point.addedBy);
    if (!mounted) return;

    final action = await PickupPointSheet.show(
      context: context,
      point: point,
      mode: PickupSheetMode.user,
      adderName: adderName,
    );

    if (!mounted || action == null || action == PickupSheetAction.close) return;

    if (action == PickupSheetAction.confirm && user != null) {
      try {
        await _pickupManager.confirmPickupPoint(
          pointId: pickupId,
          userId: user,
        );
        if (!mounted) return;
        MapUtils.showSnackBar(
          context,
          '✅ تم تأكيد هذه النقطة للمراجعة.',
          isError: false,
        );
      } catch (e) {
        if (!mounted) return;
        MapUtils.showSnackBar(context, '❌ فشل تأكيد النقطة.', isError: true);
      }
      return;
    }

    if (action == PickupSheetAction.suggestEdit && user != null) {
      final controller = TextEditingController();
      final suggested = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'اقتراح تعديل النقطة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'اكتب ما تحتاجه من تعديل أو ملاحظة',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إرسال'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (suggested == null || suggested.isEmpty) return;
      try {
        await _pickupManager.updatePickupPoint(
          pointId: pickupId,
          data: {
            'reviewNote': 'تمت مراجعة النقطة من قبل مستخدم',
            'suggestedEdit': suggested,
          },
        );
        if (!mounted) return;
        MapUtils.showSnackBar(
          context,
          '📝 تم إرسال اقتراح التعديل للمراجعة.',
          isError: false,
        );
      } catch (e) {
        if (!mounted) return;
        MapUtils.showSnackBar(
          context,
          '❌ فشل إرسال اقتراح التعديل.',
          isError: true,
        );
      }
    }
  }

  Future<void> handleAddPickupPoint(Point point) async {
    if (!_isAddingPickupPoint) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    final userData = authProvider.userData;
    if (userId == null || userData == null) {
      MapUtils.showSnackBar(
        context,
        '⚠️ يرجى تسجيل الدخول أولاً.',
        isError: true,
      );
      _isAddingPickupPoint = false;
      return;
    }

    final result = await showPickupPointPickerDialog(context: context);
    if (!mounted) return;
    if (result == null || result.name.trim().isEmpty) {
      _isAddingPickupPoint = false;
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
      MapUtils.showSnackBar(
        context,
        userData.userType == 'admin'
            ? '✅ تم إضافة النقطة وظهرت على الخرائط.'
            : '✅ تم إرسال النقطة للمراجعة.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      MapUtils.log('❌ فشل إضافة النقطة: $e', tag: 'PickupMixin');
      MapUtils.showSnackBar(context, '❌ فشل إضافة النقطة.', isError: true);
    } finally {
      if (mounted) _isAddingPickupPoint = false;
    }
  }

  void disposePickupPoints() {
    _pickupPointsSubscription?.cancel();
    _pendingSnapshot = null;
    _pickupAnnotations.clear();
    _pickupAnnotationToPointId.clear();
    _markerImageCache.clear();
    _markerVisualKey.clear();
  }
}
