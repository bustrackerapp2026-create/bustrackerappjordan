import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import '../map/map_core.dart';
import '../map/map_utils.dart';
import '../pickup/pickup_point_manager.dart';
import '../pickup/pickup_point_dialog.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../map/utils/map_helpers.dart';

mixin PickupPointMixin<T extends StatefulWidget> on MapCoreMixin<T> {
  final PickupPointManager _pickupManager = PickupPointManager();
  final Map<String, PointAnnotation> _pickupAnnotations = {};
  final Map<String, String> _pickupAnnotationToPointId = {};
  StreamSubscription<QuerySnapshot>? _pickupPointsSubscription;
  bool _isAddingPickupPoint = false;

  bool get isAddingPickupPoint => _isAddingPickupPoint;

  void toggleAddingPickupPoint() {
    _isAddingPickupPoint = !_isAddingPickupPoint;
  }

  void listenToPickupPoints() {
    _pickupPointsSubscription?.cancel();

    _pickupPointsSubscription = FirebaseFirestore.instance
        .collection('pickupPoints')
        .snapshots()
        .listen((snapshot) async {
      // ✅ التأكد من أن المدير جاهز
      if (!mounted || pointAnnotationManager == null) return;

      // ✅ نسخ القيم قبل التكرار لتجنب ConcurrentModificationError
      final annotationsToRemove = _pickupAnnotations.values.toList();
      for (final annotation in annotationsToRemove) {
        await pointAnnotationManager?.delete(annotation);
      }
      _pickupAnnotations.clear();
      _pickupAnnotationToPointId.clear();

      for (final doc in snapshot.docs) {
        final point = doc.data();
        final latitude = (point['latitude'] as num?)?.toDouble();
        final longitude = (point['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;

        // ✅ يمكن إضافة فلتر حسب الحالة هنا إذا أردت (مثل status == 'approved')
        // if (point['status'] != 'approved') continue;

        final options = PointAnnotationOptions(
          geometry: Point(coordinates: Position(longitude, latitude)),
          image: await MapHelpers.createUserMarkerBytes(),
          iconSize: 0.8,
          iconAnchor: IconAnchor.BOTTOM,
        );
        final annotation = await pointAnnotationManager?.create(options);
        if (annotation != null) {
          _pickupAnnotations[doc.id] = annotation;
          _pickupAnnotationToPointId[annotation.id] = doc.id;
        }
      }
    }, onError: (error) {
      MapUtils.log('⚠️ خطأ في جلب نقاط التجمع: $error', tag: 'PickupMixin');
    });
  }

  Future<void> showPickupPointSheet(String pickupId) async {
    final point = await _pickupManager.getPickupPoint(pointId: pickupId);
    if (!mounted) return;
    if (point == null) return;

    final user = context.read<AuthProvider>().userId;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(point.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(point.pointType == 'passenger' ? 'تجمع ركاب' : 'تجمع باصات'),
              if (point.reviewNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('ملاحظات المراجعة: ${point.reviewNote}',
                      style: const TextStyle(color: Colors.orange)),
                ),
              const SizedBox(height: 12),
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
            pointId: pickupId, userId: user);
        if (!mounted) return;
        MapUtils.showSnackBar(context, '✅ تم تأكيد هذه النقطة للمراجعة.',
            isError: false);
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
                hintText: 'اكتب ما تحتاجه من تعديل أو ملاحظة'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('إرسال')),
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
        MapUtils.showSnackBar(context, '📝 تم إرسال اقتراح التعديل للمراجعة.',
            isError: false);
      } catch (e) {
        if (!mounted) return;
        MapUtils.showSnackBar(context, '❌ فشل إرسال اقتراح التعديل.',
            isError: true);
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
      if (!mounted) return;
      MapUtils.showSnackBar(context, '⚠️ يرجى تسجيل الدخول أولاً.',
          isError: true);
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
      MapUtils.showSnackBar(context, '✅ تم إرسال النقطة للمراجعة.',
          isError: false);
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
  }
}
