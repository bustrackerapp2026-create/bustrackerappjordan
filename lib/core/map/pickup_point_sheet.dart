import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/pickup_point_model.dart';
import '../pickup/pickup_marker_helper.dart';
import '../theme/app_theme.dart';

/// نتيجة اختيار المستخدم من بطاقة نقطة التجمع
enum PickupSheetAction {
  confirm,
  suggestEdit,
  edit,
  delete,
  approve,
  reject,
  close,
}

/// وضع العرض حسب الدور
enum PickupSheetMode {
  /// راكب / سائق: تأكيد + اقتراح تعديل
  user,

  /// أدمن: تعديل + حذف (+ اعتماد/رفض إن كانت معلقة)
  admin,
}

/// بطاقة معلومات نقطة التجمع — تصميم موحّد وجذاب لكل الخرائط.
class PickupPointSheet {
  PickupPointSheet._();

  static Future<PickupSheetAction?> show({
    required BuildContext context,
    required PickupPointModel point,
    PickupSheetMode mode = PickupSheetMode.user,
    String? adderName,
  }) async {
    final color = PickupMarkerHelper.primaryColorFor(point.pointType);
    final icon = PickupMarkerHelper.iconFor(point.pointType);
    final typeLabel =
        point.pointType == 'passenger' ? 'تجمع ركاب' : 'تجمع باصات';
    final typeEmoji = point.pointType == 'passenger' ? '🚶' : '🚌';

    final statusColor = _statusColor(point.status);
    final statusLabel = _statusLabel(point.status);

    return showModalBottomSheet<PickupSheetAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).padding.bottom;

        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: bottomPad + 12,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شريط علوي ملون
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.55)],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // مقبض
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),

                        // الرأس: أيقونة + اسم + نوع
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    color.withValues(alpha: 0.2),
                                    color.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.28),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: color, size: 32),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    point.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _chip(
                                        label: '$typeEmoji $typeLabel',
                                        color: color,
                                      ),
                                      _chip(
                                        label: statusLabel,
                                        color: statusColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  Navigator.pop(ctx, PickupSheetAction.close),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // بطاقة الإحصائيات
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _statItem(
                                    icon: Icons.verified_user_rounded,
                                    label: 'التأكيدات',
                                    value: '${point.confirmationCount}',
                                    color: Colors.teal,
                                  ),
                                  _divider(),
                                  _statItem(
                                    icon: Icons.person_outline_rounded,
                                    label: 'أضافها',
                                    value: adderName ??
                                        _userTypeLabel(point.addedByUserType),
                                    color: AppTheme.primaryColor,
                                  ),
                                ],
                              ),
                              if (point.latitude != 0 &&
                                  point.longitude != 0) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.my_location_rounded,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ملاحظات المراجعة
                        if (point.reviewNote.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _noteBox(
                            title: 'ملاحظات المراجعة',
                            text: point.reviewNote,
                            color: Colors.orange,
                            icon: Icons.notes_rounded,
                          ),
                        ],

                        if (point.suggestedEdit.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _noteBox(
                            title: 'اقتراح تعديل',
                            text: point.suggestedEdit,
                            color: Colors.indigo,
                            icon: Icons.edit_note_rounded,
                          ),
                        ],

                        const SizedBox(height: 18),

                        // الأزرار حسب الوضع
                        if (mode == PickupSheetMode.user)
                          _userActions(ctx, color)
                        else
                          _adminActions(ctx, point, color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── واجهة الأزرار ─────────────────────────────────────────────

  static Widget _userActions(BuildContext ctx, Color color) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pop(ctx, PickupSheetAction.confirm),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text(
                'هذا صحيح',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(ctx, PickupSheetAction.suggestEdit),
              icon: Icon(Icons.edit_note_rounded, size: 20, color: color),
              label: Text(
                'أحتاج تعديل',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _adminActions(
    BuildContext ctx,
    PickupPointModel point,
    Color color,
  ) {
    return Column(
      children: [
        if (point.isPending) ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(ctx, PickupSheetAction.approve),
                    icon: const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('اعتماد',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(ctx, PickupSheetAction.reject),
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: const Text('رفض',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, PickupSheetAction.edit),
                  icon: Icon(Icons.edit_rounded, size: 18, color: color),
                  label: Text(
                    'تعديل',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(ctx, PickupSheetAction.delete),
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red.shade600),
                  label: Text(
                    'حذف',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── عناصر مساعدة ──────────────────────────────────────────────

  static Widget _chip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.shade300,
    );
  }

  static Widget _noteBox({
    required String title,
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return '✓ معتمدة';
      case 'rejected':
        return '✕ مرفوضة';
      default:
        return '⏳ قيد المراجعة';
    }
  }

  static String _userTypeLabel(String type) {
    switch (type) {
      case 'driver':
        return 'سائق';
      case 'passenger':
        return 'راكب';
      case 'admin':
        return 'أدمن';
      default:
        return type;
    }
  }

  /// جلب اسم مُضيف النقطة من Firestore (اختياري)
  static Future<String> loadAdderName(String userId) async {
    if (userId.isEmpty) return 'غير معروف';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final name = doc.data()?['fullName'] as String?;
      return (name != null && name.trim().isNotEmpty) ? name.trim() : 'بدون اسم';
    } catch (_) {
      return 'تعذر جلب الاسم';
    }
  }
}
