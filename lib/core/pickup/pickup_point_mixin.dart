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
import 'pickup_marker_helper.dart';
import 'pickup_point_dialog.dart';
import 'pickup_point_manager.dart';

/// مكسين مشترك لعرض وإدارة نقاط التجمع على خرائط السائق (وأي خريطة تستخدم MapCore).
///
/// - يستمع فقط للنقاط المعتمدة (approved) لمزامنة فورية مع الأدمن.
/// - يرسم علامات مميزة: باصات (برتقالي) / ركاب (نيلي).
mixin PickupPointMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, String> _pickupAnnotationToPointId = {};
  final Map<String, Uint8List> _markerImageCache = {};
  StreamSubscription<QuerySnapshot>? _pickupPointsSubscription;
  bool _isAddingPickupPoint = false;

  bool get isAddingPickupPoint => _isAddingPickupPoint;

  Map<String, PointAnnotation> get pickupAnnotations => _pickupAnnotations;

  void toggleAddingPickupPoint() {
    _isAddingPickupPoint = !_isAddingPickupPoint;
  }

  /// الاستماع اللحظي لنقاط التجمع المعتمدة من Firestore
  void listenToPickupPoints() {
    _pickupPointsSubscription?.cancel();

    _pickupPointsSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen(
      (snapshot) {
        MapUtils.log(
          '📦 [Pickup] استلام ${snapshot.docs.length} نقطة معتمدة',
          tag: 'PickupMixin',
        );
        _syncPickupMarkers(snapshot);
      },
      onError: (error) {
        MapUtils.log('⚠️ خطأ في جلب نقاط التجمع: $error', tag: 'PickupMixin');
      },
    );
  }

  Future<void> _syncPickupMarkers(QuerySnapshot snapshot) async {
    // إذا لم يكن المدير جاهزاً بعد، ننتظر قليلاً ثم نعيد المحاولة
    if (!mounted) return;
    if (pointAnnotationManager == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || pointAnnotationManager == null) return;
    }

    final incomingIds = snapshot.docs.map((d) => d.id).toSet();
    final existingIds = _pickupAnnotations.keys.toSet();

    // حذف النقاط التي أُزيلت أو لم تعد معتمدة
    for (final id in existingIds.difference(incomingIds)) {
      final annotation = _pickupAnnotations.remove(id);
      if (annotation != null) {
        try {
          await pointAnnotationManager?.delete(annotation);
        } catch (_) {}
        _pickupAnnotationToPointId.remove(annotation.id);
      }
    }

    for (final doc in snapshot.docs) {
      if (!mounted) return;
      try {
        final point = PickupPointModel.fromFirestore(doc);
        if (point.latitude == 0.0 && point.longitude == 0.0) continue;

        await _upsertPickupMarker(point);
      } catch (e) {
        MapUtils.log(
          '⚠️ خطأ في معالجة نقطة ${doc.id}: $e',
          tag: 'PickupMixin',
        );
      }
    }

    MapUtils.log(
      '✅ [Pickup] معروض ${_pickupAnnotations.length} نقطة على الخريطة',
      tag: 'PickupMixin',
    );
  }

  Future<void> _upsertPickupMarker(PickupPointModel point) async {
    if (pointAnnotationManager == null || !mounted) return;

    // إزالة القديمة إن وُجدت ثم إعادة الإنشاء بصورة محدّثة
    final existing = _pickupAnnotations.remove(point.id);
    if (existing != null) {
      try {
        await pointAnnotationManager?.delete(existing);
      } catch (_) {}
      _pickupAnnotationToPointId.remove(existing.id);
    }

    final bytes = await _markerBytesFor(point);
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
    }
  }

  Future<Uint8List?> _markerBytesFor(PickupPointModel point) async {
    final key =
        '${point.id}_${point.pointType}_${point.name.hashCode}_${point.confirmationCount}';
    final cached = _markerImageCache[key];
    if (cached != null) return cached;

    final bytes = await PickupMarkerHelper.createMarkerBytes(
      name: point.name,
      pointType: point.pointType,
      confirmationCount: point.confirmationCount,
    );
    if (bytes != null) _markerImageCache[key] = bytes;
    return bytes;
  }

  String? findPickupIdByAnnotation(PointAnnotation annotation) {
    return _pickupAnnotationToPointId[annotation.id];
  }

  Future<void> showPickupPointSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted) return;
    if (point == null) return;

    final user = context.read<AuthProvider>().userId;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: PickupMarkerHelper.primaryColorFor(
                      point.pointType,
                    ).withValues(alpha: 0.15),
                    child: Icon(
                      PickupMarkerHelper.iconFor(point.pointType),
                      color: PickupMarkerHelper.primaryColorFor(point.pointType),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          point.pointType == 'passenger'
                              ? '🚶 تجمع ركاب'
                              : '🚌 تجمع باصات',
                          style: TextStyle(
                            color: PickupMarkerHelper.primaryColorFor(
                              point.pointType,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (point.reviewNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'ملاحظات المراجعة: ${point.reviewNote}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: user == null
                          ? null
                          : () => Navigator.pop(sheetContext, 'confirm'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('هذا صحيح'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: user == null
                          ? null
                          : () => Navigator.pop(sheetContext, 'edit'),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('أحتاج تعديل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (action == 'confirm' && user != null) {
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

    if (action == 'edit' && user != null) {
      final controller = TextEditingController();
      final suggested = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('اقتراح تعديل النقطة'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب ما تحتاجه من تعديل أو ملاحظة',
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
    _pickupAnnotations.clear();
    _pickupAnnotationToPointId.clear();
    _markerImageCache.clear();
  }
}
