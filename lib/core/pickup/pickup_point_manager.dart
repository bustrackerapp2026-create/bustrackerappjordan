import '../../services/pickup_point_service.dart';
import '../../models/pickup_point_model.dart';
import '../map/map_utils.dart';

/// مكسين مشترك لإدارة نقاط التجمع (يُستخدم في جميع الخرائط)
///
/// يحتوي على منطق الأعمال لإضافة وتحديث وحذف النقاط.
/// يتم التعامل مع الصلاحيات بناءً على [userType].
class PickupPointManager {
  // ─── الخدمة ──────────────────────────────────────────────────────
  final PickupPointService _pickupService = PickupPointService();

  // ─── دوال الإدارة ────────────────────────────────────────────────

  /// ✅ إضافة نقطة تجمع جديدة
  ///
  /// [name] اسم النقطة
  /// [latitude] خط العرض
  /// [longitude] خط الطول
  /// [userId] معرف المستخدم المضيف
  /// [userType] نوع المستخدم (admin, driver, passenger)
  ///
  /// تعود بـ [String] معرف النقطة الجديدة
  Future<String> addPickupPoint({
    required String name,
    required double latitude,
    required double longitude,
    required String userId,
    required String userType,
  }) async {
    try {
      // إنشاء كائن النقطة (بدون id)
      final point = PickupPointModel(
        id: '', // سيتم توليده تلقائياً في الخدمة
        name: name,
        latitude: latitude,
        longitude: longitude,
        addedBy: userId,
        addedByUserType: userType,
        status: userType == 'admin' ? 'approved' : 'pending',
        confirmations: const [],
        confirmationCount: 0,
      );

      // إضافة النقطة مع تحديد الدور
      final pointId = await _pickupService.addPickupPointWithRole(
        point: point,
        userId: userId,
        userType: userType,
      );

      MapUtils.log('✅ تم إضافة نقطة جديدة: $name (ID: $pointId)',
          tag: 'PickupManager');
      return pointId;
    } catch (e) {
      MapUtils.log('❌ فشل إضافة النقطة: $e', tag: 'PickupManager');
      rethrow;
    }
  }

  /// ✅ تحديث نقطة تجمع موجودة (للأدمن فقط)
  Future<void> updatePickupPoint({
    required String pointId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _pickupService.updatePickupPoint(pointId: pointId, data: data);
      MapUtils.log('✅ تم تحديث النقطة $pointId', tag: 'PickupManager');
    } catch (e) {
      MapUtils.log('❌ فشل تحديث النقطة: $e', tag: 'PickupManager');
      rethrow;
    }
  }

  /// ✅ حذف نقطة تجمع (للأدمن فقط)
  Future<void> deletePickupPoint({required String pointId}) async {
    try {
      await _pickupService.deletePickupPoint(pointId);
      MapUtils.log('🗑️ تم حذف النقطة $pointId', tag: 'PickupManager');
    } catch (e) {
      MapUtils.log('❌ فشل حذف النقطة: $e', tag: 'PickupManager');
      rethrow;
    }
  }

  /// ✅ تأكيد نقطة تجمع (زيادة عدد التأكيدات)
  Future<void> confirmPickupPoint({
    required String pointId,
    required String userId,
  }) async {
    try {
      await _pickupService.confirmPickupPoint(pointId: pointId, userId: userId);
      MapUtils.log('✅ تم تأكيد النقطة $pointId بواسطة $userId',
          tag: 'PickupManager');
    } catch (e) {
      MapUtils.log('❌ فشل تأكيد النقطة: $e', tag: 'PickupManager');
      rethrow;
    }
  }

  /// ✅ جلب نقطة واحدة
  Future<PickupPointModel?> getPickupPoint({required String pointId}) async {
    try {
      return await _pickupService.getPickupPoint(pointId);
    } catch (e) {
      MapUtils.log('❌ فشل جلب النقطة: $e', tag: 'PickupManager');
      return null;
    }
  }

  /// ✅ التحقق من صلاحية التعديل
  bool canEdit(String userType) {
    return userType == 'admin';
  }

  /// ✅ التحقق من صلاحية الحذف
  bool canDelete(String userType) {
    return userType == 'admin';
  }

  /// ✅ التحقق من صلاحية التأكيد
  bool canConfirm(String userType) {
    return true; // جميع المستخدمين يمكنهم التأكيد
  }
}
