import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// حوار إضافة نقطة تجمع جديدة
class PickupPointDialog extends StatelessWidget {
  final Function(String name) onConfirm;

  const PickupPointDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return AlertDialog(
      title: const Text(
        'إضافة نقطة تجمع الباصات/الركاب',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
        textAlign: TextAlign.right,
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اسم النقطة',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'أدخل اسم النقطة (مثل: مجمع الشمال)',
                hintTextDirection: TextDirection.rtl,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال اسم النقطة';
                }
                if (value.trim().length < 3) {
                  return 'اسم النقطة يجب أن يكون 3 أحرف على الأقل';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
          ),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final name = nameController.text.trim();
              onConfirm(name);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  /// ✅ دالة لعرض الحوار وإرجاع اسم النقطة
  static Future<String?> show({
    required BuildContext context,
  }) async {
    String? result;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PickupPointDialog(
        onConfirm: (name) {
          result = name;
        },
      ),
    );
    return result;
  }
}
