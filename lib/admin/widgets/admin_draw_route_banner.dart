import 'package:flutter/material.dart';

/// شريط أدوات رسم المسار على خريطة الأدمن.
class AdminDrawRouteBanner extends StatelessWidget {
  final int drawPointCount;
  final bool isSnappingSegment;
  final VoidCallback? onSave;
  final VoidCallback? onUndo;
  final VoidCallback onCancel;

  const AdminDrawRouteBanner({
    super.key,
    required this.drawPointCount,
    required this.isSnappingSegment,
    required this.onSave,
    required this.onUndo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(14),
      color: const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isSnappingSegment
                  ? 'جاري لصق القطعة على الشارع…'
                  : 'رسم على الشارع · $drawPointCount نقطة — انقر بالتسلسل',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF6D28D9),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('حفظ وتسمية'),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: onUndo,
                  child: const Text('تراجع'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
