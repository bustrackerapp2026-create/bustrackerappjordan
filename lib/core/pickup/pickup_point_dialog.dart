import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PickupPointDialogResult {
  final String name;
  final String pointType;

  const PickupPointDialogResult({
    required this.name,
    required this.pointType,
  });
}

/// حوار إضافة نقطة تجمع جديدة
class PickupPointDialog extends StatefulWidget {
  final Function(String name, String pointType) onConfirm;
  final String initialName;
  final String initialPointType;

  const PickupPointDialog({
    super.key,
    required this.onConfirm,
    this.initialName = '',
    this.initialPointType = 'bus',
  });

  @override
  State<PickupPointDialog> createState() => _PickupPointDialogState();
}

class _PickupPointDialogState extends State<PickupPointDialog> {
  late final TextEditingController nameController;
  late String selectedPointType;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    selectedPointType = widget.initialPointType;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 16),
            const Text(
              'اختر نوع النقطة',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    label: 'تجمع باصات',
                    value: 'bus',
                    icon: Icons.directions_bus_rounded,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeOption(
                    label: 'تجمع ركاب',
                    value: 'passenger',
                    icon: Icons.people_alt_rounded,
                    color: Colors.indigo,
                  ),
                ),
              ],
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
              widget.onConfirm(name, selectedPointType);
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

  Widget _buildTypeOption({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedPointType == value;
    return InkWell(
      onTap: () => setState(() => selectedPointType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withValues(alpha: 0.16) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ دالة لعرض الحوار وإرجاع اسم النقطة ونوعها
  static Future<PickupPointDialogResult?> showPickerDialog({
    required BuildContext context,
    String initialName = '',
    String initialPointType = 'bus',
  }) async {
    return showPickupPointPickerDialog(
      context: context,
      initialName: initialName,
      initialPointType: initialPointType,
    );
  }
}

Future<PickupPointDialogResult?> showPickupPointPickerDialog({
  required BuildContext context,
  String initialName = '',
  String initialPointType = 'bus',
}) async {
  PickupPointDialogResult? result;
  await showDialog<PickupPointDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => PickupPointDialog(
      initialName: initialName,
      initialPointType: initialPointType,
      onConfirm: (name, pointType) {
        result = PickupPointDialogResult(name: name, pointType: pointType);
      },
    ),
  );
  return result;
}
